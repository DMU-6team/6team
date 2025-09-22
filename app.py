import os
import sounddevice as sd
import soundfile as sf
import numpy as np
import librosa
import threading 
import time
import joblib
from flask import Flask, render_template, Response
from flask_sqlalchemy import SQLAlchemy
import cv2 
import serial
import mediapipe as mp

# ───────────── 설정 ─────────────
INPUT_SR = 44100
TARGET_SR = 16000
DURATION = 2
N_MFCC = 13
MAX_LEN = 40
MODEL_PATH = "knn_model.joblib"
DEVICE_INDEX = 2
TEMP_AUDIO_FILE = "temp_resampled.wav"

app = Flask(__name__)

# ─── DB 설정  ───
app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql+mysqlconnector://root:root@localhost/baby'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# ─── Mediapipe 세팅 ───
mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh(
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

baby_direction = "확인 중..."

# ─── 체온 데이터를 저장할 모델 (테이블 정의) ───
class Temperature(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    temp = db.Column(db.Float, nullable=False)
    timestamp = db.Column(db.DateTime, default=db.func.current_timestamp())

# DB 초기화 (애플리케이션 컨텍스트 안에서 실행)
with app.app_context():
    db.create_all()

# ───────── 울음소리 판별 ─────────
def record_resample():
    try:
        audio = sd.rec(int(DURATION * INPUT_SR), samplerate=INPUT_SR,
                       channels=1, dtype='float32', device=DEVICE_INDEX)
        sd.wait()
        audio = audio.flatten()
        y_resampled = librosa.resample(audio, orig_sr=INPUT_SR, target_sr=TARGET_SR)
        sf.write(TEMP_AUDIO_FILE, y_resampled, TARGET_SR)
    except Exception as e:
        print(f"[ERROR] 녹음 실패: {e}")

def extract_mfcc(file_path):
    try:
        y, sr = librosa.load(file_path, sr=TARGET_SR, duration=DURATION)
        mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=N_MFCC)
        if mfcc.shape[1] < MAX_LEN:
            mfcc = np.pad(mfcc, ((0, 0), (0, MAX_LEN - mfcc.shape[1])), mode='constant')
        else:
            mfcc = mfcc[:, :MAX_LEN]
        return mfcc.flatten()
    except Exception as e:
        print(f"[ERROR] MFCC 추출 실패: {e}")
        return None

crying_status = "확인 중..."

def predict_cry():
    global crying_status
    mfcc = extract_mfcc(TEMP_AUDIO_FILE)
    if mfcc is None:
        return
    try:
        model = joblib.load(MODEL_PATH)
        result = model.predict([mfcc])[0]
        prob = model.predict_proba([mfcc])[0][1]
        print(f"🍼 Result: {'Crying' if result == 1 else 'Not Crying'} (Cry probability: {prob:.3f})")
        crying_status = "Crying" if result == 1 else "Silent"
    except FileNotFoundError:
        print(f"[ERROR] 모델 파일을 찾을 수 없습니다: {MODEL_PATH}")
        crying_status = "모델 에러"

def cry_monitor_loop():
    while True:
        record_resample()
        predict_cry()
        time.sleep(1)

# ───────── USB 카메라 자동 탐색 ─────────
def find_working_camera():
    for i in range(1, 5):
        cap = cv2.VideoCapture(i)
        if cap.isOpened():
            ret, _ = cap.read()
            cap.release()
            if ret:
                print(f"✅ USB 카메라 {i}에서 작동 확인됨")
                return i
    raise RuntimeError("❌ 사용 가능한 USB 카메라를 찾을 수 없습니다.")

try:
    CAM_INDEX = find_working_camera()
    cap = cv2.VideoCapture(CAM_INDEX)
    time.sleep(2)
    if not cap.isOpened():
        raise RuntimeError("❌ 카메라 초기화 실패")
except RuntimeError as e:
    print(e)
    cap = None
    baby_direction = "카메라 에러"

# ───────── 시리얼 설정 ─────────
try:
    ser = serial.Serial('/dev/ttyACM0', 9600)
    temperature = "체온 체크 중..."
except Exception as e:
    print("Serial 연결 실패:", e)
    ser = None
    temperature = "Error"

servo_active = False

def read_serial():
    global temperature
    if not ser:
        return
    while True:
        try:
            if ser.in_waiting > 0:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                print("Serial >", line)
                if "아기 체온:" in line:
                    temp_str = line.replace("아기 체온:", "").replace("\u00b0C", "").strip()
                    try:
                        temp_float = float(temp_str)
                        temperature = temp_float
                        
                        # 🌡️ DB에 체온 저장
                        with app.app_context():
                            new_temp = Temperature(temp=temp_float)
                            db.session.add(new_temp)
                            db.session.commit()
                        print(f"✅ DB에 체온 {temp_float}°C 저장 완료")
                    except ValueError:
                        print("유효하지 않은 체온 값:", temp_str)
                        temperature = "Error"
        except Exception as e:
            print("Serial Read Error:", e)
            temperature = "Error"

def servo_loop():
    while servo_active and ser:
        try:
            ser.write(b'servo\n')
            time.sleep(2)
        except Exception as e:
            print("Servo Error:", e)
            break

# ─────── 영상 스트리밍 ───────
def gen_frames():
    global baby_direction
    while True:
        if not cap:
            time.sleep(1)
            continue
        
        ret, frame = cap.read()
        if not ret:
            print("[ERROR] 프레임 캡처 실패")
            baby_direction = "카메라 에러"
            continue

        image = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = face_mesh.process(image)
        image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)

        if results.multi_face_landmarks:
            face_landmarks = results.multi_face_landmarks[0]
            nose_tip = face_landmarks.landmark[1]
            left_eye = face_landmarks.landmark[33]
            right_eye = face_landmarks.landmark[263]

            center_x = (left_eye.x + right_eye.x) / 2
            dx = nose_tip.x - center_x

            threshold = 0.02
            if abs(dx) < threshold:
                baby_direction = "정면 유지 중"
            elif dx < 0:
                baby_direction = "우측으로 움직임"
            else:
                baby_direction = "좌측으로 움직임"
        else:
            baby_direction = "인식 안됨"

        _, buffer = cv2.imencode('.jpg', image)
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')

# ─────── Flask 라우팅 ───────
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/video_feed')
def video_feed():
    return Response(gen_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/temperature_stream')
def temperature_stream():
    def generate():
        while True:
            yield f"data: {temperature}\n\n"
            time.sleep(1)
    return Response(generate(), mimetype='text/event-stream')

@app.route('/crying_status')
def crying_status_route():
    def generate():
        while True:
            yield f"data: {crying_status}\n\n"
            time.sleep(1)
    return Response(generate(), mimetype='text/event-stream')

@app.route('/baby_direction')
def baby_direction_stream():
    def generate():
        while True:
            yield f"data: {baby_direction}\n\n"
            time.sleep(1)
    return Response(generate(), mimetype='text/event-stream')

@app.route('/toggle_servo')
def toggle_servo():
    global servo_active
    if not servo_active:
        servo_active = True
        threading.Thread(target=servo_loop, daemon=True).start()
        return "Servo ON"
    else:
        servo_active = False
        return "Servo OFF"

# ─────── 스레드 시작 ───────
threading.Thread(target=read_serial, daemon=True).start()
threading.Thread(target=cry_monitor_loop, daemon=True).start()

# ─────── 웹 앱 시작 ───────
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
