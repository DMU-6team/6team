import os
import time
import threading
import queue
import cv2
import serial
import joblib
import librosa
import numpy as np
import sounddevice as sd
import soundfile as sf
import mediapipe as mp
from flask import Flask, render_template, Response, jsonify
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 주요 설정
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 모든 설정을 쉽게 변경할 수 있도록 한 곳에 모아둡니다.
CONFIG = {
    # 오디오 설정
    "INPUT_SR": 44100,
    "TARGET_SR": 16000,
    "DURATION": 2,  # 초
    "N_MFCC": 13,
    "MAX_LEN": 40,
    "AUDIO_DEVICE_INDEX": None, # 특정 번호(예: 2)로 설정하거나, 기본 장치를 사용하려면 None으로 설정
    # 모델 경로
    "MODEL_PATH": "knn_model.joblib",
    # 시리얼 포트
    "SERIAL_PORT": "/dev/ttyACM0",
    "SERIAL_BAUDRATE": 9600,
    # 데이터베이스
    "DATABASE_URI": 'sqlite:///' + os.path.join(os.path.abspath(os.path.dirname(__file__)), 'baby_monitor.db'),
    "LOGGING_INTERVAL": 10, # 초
    # 카메라
    "CAMERA_SEARCH_RANGE": 5, # 카메라 인덱스 0부터 4까지 확인
    # 얼굴 감지
    "FACE_DIRECTION_THRESHOLD": 0.02,
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 플라스크 및 데이터베이스 설정
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = CONFIG["DATABASE_URI"]
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# --- 데이터베이스 모델 (SensorLog 테이블) ---
# 모든 센서 데이터를 주기적으로 기록하기 위한 테이블
class SensorLog(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    temperature = db.Column(db.String(50))
    crying_status = db.Column(db.String(50))
    baby_direction = db.Column(db.String(50))

    def __repr__(self):
        return f'<Log {self.timestamp} - T:{self.temperature} Crying:{self.crying_status} Dir:{self.baby_direction}>'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 스레드 간 공유 데이터 및 잠금
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 안정성을 위해 전역 변수 대신 스레드에 안전한 잠금을 사용합니다.
shared_state = {
    "crying_status": "초기화 중...",
    "baby_direction": "초기화 중...",
    "temperature": "초기화 중...",
    "servo_active": False,
    "camera_error": False,
    "serial_error": False,
}
state_lock = threading.Lock()
servo_event = threading.Event()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 미디어파이프 및 모델 초기화
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh(
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

try:
    cry_model = joblib.load(CONFIG["MODEL_PATH"])
except FileNotFoundError:
    print(f"[ERROR] 울음 감지 모델을 찾을 수 없습니다: {CONFIG['MODEL_PATH']}")
    cry_model = None
    with state_lock:
        shared_state["crying_status"] = "모델 오류"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 울음소리 감지 모듈
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def process_cry_detection():
    """
    별도 스레드에서 실행되는 울음소리 감지 메인 루프.
    오디오를 녹음하고, 특징을 추출하여 예측합니다.
    """
    if not cry_model:
        print("[INFO] 울음 감지 모델이 로드되지 않았습니다. 울음 감지를 건너뜁니다.")
        return

    while True:
        try:
            # 1. 오디오 녹음
            audio_data = sd.rec(
                int(CONFIG["DURATION"] * CONFIG["INPUT_SR"]),
                samplerate=CONFIG["INPUT_SR"],
                channels=1,
                dtype='float32',
                device=CONFIG["AUDIO_DEVICE_INDEX"]
            )
            sd.wait()

            # 2. 오디오 리샘플링
            y_resampled = librosa.resample(audio_data.flatten(), orig_sr=CONFIG["INPUT_SR"], target_sr=CONFIG["TARGET_SR"])

            # 3. MFCC 특징 추출
            mfcc = librosa.feature.mfcc(y=y_resampled, sr=CONFIG["TARGET_SR"], n_mfcc=CONFIG["N_MFCC"])
            
            # MFCC 데이터 길이 맞추기
            if mfcc.shape[1] < CONFIG["MAX_LEN"]:
                mfcc = np.pad(mfcc, ((0, 0), (0, CONFIG["MAX_LEN"] - mfcc.shape[1])), mode='constant')
            else:
                mfcc = mfcc[:, :CONFIG["MAX_LEN"]]
            
            mfcc_flat = mfcc.flatten()

            # 4. 모델로 예측
            result = cry_model.predict([mfcc_flat])[0]
            
            new_status = "Crying" if result == 1 else "Silent"
            with state_lock:
                shared_state["crying_status"] = new_status
            
        except Exception as e:
            print(f"[ERROR] 울음 감지 루프 오류: {e}")
            with state_lock:
                shared_state["crying_status"] = "오디오 오류"
            time.sleep(5)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 시리얼 통신 모듈 (온도, 서보 제어)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def manage_serial_connection():
    """
    시리얼 포트를 통해 온도를 읽고 서보 모터를 제어합니다.
    """
    global ser
    try:
        ser = serial.Serial(CONFIG["SERIAL_PORT"], CONFIG["SERIAL_BAUDRATE"], timeout=1)
        print(f"✅ 시리얼 연결 성공: {CONFIG['SERIAL_PORT']}")
        with state_lock:
            shared_state["serial_error"] = False
    except serial.SerialException as e:
        print(f"❌ 시리얼 연결 실패: {e}")
        ser = None
        with state_lock:
            shared_state["serial_error"] = True
            shared_state["temperature"] = "시리얼 오류"
        return
        
    def read_temp():
        while True:
            try:
                if ser and ser.in_waiting > 0:
                    line = ser.readline().decode('utf-8', errors='ignore').strip()
                    if "아기 체온:" in line:
                        temp_str = line.split(":")[-1].replace("C", "").strip()
                        temp_float = float(temp_str)
                        with state_lock:
                            shared_state["temperature"] = f"{temp_float:.1f}"
            except Exception as e:
                print(f"[ERROR] 시리얼 읽기 오류: {e}")
                with state_lock:
                    shared_state["temperature"] = "시리얼 오류"
                break
        print("[INFO] 온도 읽기 스레드 중지됨.")
    
    def control_servo():
        while True:
            servo_event.wait()
            try:
                if ser:
                    ser.write(b'servo\n')
                    time.sleep(2)
                else:
                    servo_event.clear()
            except Exception as e:
                print(f"[ERROR] 시리얼 쓰기(서보) 오류: {e}")
                servo_event.clear()
        print("[INFO] 서보 제어 스레드 중지됨.")

    threading.Thread(target=read_temp, daemon=True).start()
    threading.Thread(target=control_servo, daemon=True).start()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 비디오 스트리밍 및 얼굴 방향 분석 모듈
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def find_working_camera():
    """사용 가능한 USB 카메라를 찾습니다."""
    for i in range(CONFIG["CAMERA_SEARCH_RANGE"]):
        cap = cv2.VideoCapture(i)
        if cap.isOpened():
            print(f"✅ 카메라를 찾았습니다 (인덱스 {i})")
            return cap
    return None

def generate_video_frames():
    """
    프레임을 캡처하고, 얼굴 방향을 처리하여 스트리밍을 위해 전송합니다.
    """
    cap = find_working_camera()
    if not cap:
        print("❌ 사용 가능한 카메라를 찾을 수 없습니다.")
        with state_lock:
            shared_state["camera_error"] = True
            shared_state["baby_direction"] = "카메라 오류"
        return

    while True:
        ret, frame = cap.read()
        if not ret:
            print("[ERROR] 프레임 캡처 실패.")
            with state_lock:
                shared_state["baby_direction"] = "카메라 오류"
            cap.release()
            cap = find_working_camera()
            if not cap:
                break
            continue

        image = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        image.flags.writeable = False
        results = face_mesh.process(image)
        image.flags.writeable = True
        image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)

        new_direction = "감지 안됨"
        if results.multi_face_landmarks:
            for face_landmarks in results.multi_face_landmarks:
                nose_tip = face_landmarks.landmark[1]
                left_eye = face_landmarks.landmark[33]
                right_eye = face_landmarks.landmark[263]
                
                center_x = (left_eye.x + right_eye.x) / 2
                dx = nose_tip.x - center_x

                threshold = CONFIG["FACE_DIRECTION_THRESHOLD"]
                if abs(dx) < threshold:
                    new_direction = "정면"
                elif dx < 0:
                    new_direction = "오른쪽으로 이동"
                else:
                    new_direction = "왼쪽으로 이동"
        
        with state_lock:
            shared_state["baby_direction"] = new_direction

        _, buffer = cv2.imencode('.jpg', frame)
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')
    
    cap.release()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 데이터베이스 로깅 모듈
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def log_sensor_data_periodically():
    """
    현재 센서 상태를 데이터베이스에 주기적으로 저장합니다.
    잦은 쓰기를 방지하기 위해 별도 스레드에서 실행됩니다.
    """
    while True:
        time.sleep(CONFIG["LOGGING_INTERVAL"])
        
        with app.app_context():
            with state_lock:
                # DB 작업 중 lock을 오래 잡고 있지 않도록 상태를 복사
                current_state = shared_state.copy()
            
            # 초기 기본값은 로그에 기록하지 않음
            if "초기화 중..." in current_state.values():
                continue

            try:
                new_log = SensorLog(
                    temperature=current_state["temperature"],
                    crying_status=current_state["crying_status"],
                    baby_direction=current_state["baby_direction"]
                )
                db.session.add(new_log)
                db.session.commit()
            except Exception as e:
                print(f"[ERROR] 센서 데이터 DB 로깅 실패: {e}")
                db.session.rollback()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 플라스크 라우트 (API 엔드포인트)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/video_feed')
def video_feed():
    return Response(generate_video_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/status')
def status_stream():
    def generate():
        while True:
            with state_lock:
                current_state = shared_state.copy()
            yield f"data: {jsonify(current_state).get_data(as_text=True)}\n\n"
            time.sleep(1)
    return Response(generate(), mimetype='text/event-stream')

@app.route('/toggle_servo')
def toggle_servo():
    with state_lock:
        if shared_state["servo_active"]:
            servo_event.clear()
            shared_state["servo_active"] = False
            message = "Servo OFF"
        else:
            servo_event.set()
            shared_state["servo_active"] = True
            message = "Servo ON"
    return message
    
@app.route('/log_history')
def log_history():
    """최근 20개의 센서 로그 항목을 반환합니다."""
    with app.app_context():
        readings = SensorLog.query.order_by(SensorLog.timestamp.desc()).limit(20).all()
        history = [
            {
                "time": r.timestamp.strftime("%Y-%m-%d %H:%M:%S"),
                "temp": r.temperature,
                "crying": r.crying_status,
                "direction": r.baby_direction,
            } for r in readings
        ]
        return jsonify(history)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 메인 실행
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if __name__ == '__main__':
    # 데이터베이스 테이블이 없으면 생성
    with app.app_context():
        db.create_all()

    # 백그라운드 스레드 시작
    threading.Thread(target=process_cry_detection, daemon=True).start()
    threading.Thread(target=manage_serial_connection, daemon=True).start()
    threading.Thread(target=log_sensor_data_periodically, daemon=True).start() # DB 로깅 스레드

    # 플라스크 앱 실행
    print("🚀 플라스크 서버를 시작합니다 http://0.0.0.0:8080")
    app.run(host='0.0.0.0', port=8080, debug=False, threaded=True)

