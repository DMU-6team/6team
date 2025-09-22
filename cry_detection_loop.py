import sounddevice as sd
import soundfile as sf
import numpy as np 
import librosa
import time
from sklearn.neighbors import KNeighborsClassifier
import joblib

# 설정
INPUT_SR = 44100           # 마이크 기본 입력 샘플링레이트 (ex: 44100 또는 48000)
TARGET_SR = 16000          # 우리가 사용할 모델용 샘플링레이트
DURATION = 2               # 녹음 시간 (초)
N_MFCC = 13
MAX_LEN = 40
MODEL_PATH = "knn_model.joblib"
DEVICE_INDEX = 2           # USB 마이크 장치 번호 (예: Scarlett 2i2 = 2)

# 마이크로 녹음 → 16kHz 리샘플링 → 저장
def record_resample(filename="temp_resampled.wav"):
    print("🎙️ 녹음 시작...")
    try:
        audio = sd.rec(int(DURATION * INPUT_SR), samplerate=INPUT_SR,
                       channels=1, dtype='float32', device=DEVICE_INDEX)
        sd.wait()
        audio = audio.flatten()

        print(f"🔄 {INPUT_SR}Hz → {TARGET_SR}Hz 리샘플링 중...")
        resampled = librosa.resample(audio, orig_sr=INPUT_SR, target_sr=TARGET_SR)

        sf.write(filename, resampled, TARGET_SR)
        print("📁 저장 완료:", filename)
    except Exception as e:
        print(f"[ERROR] 녹음/리샘플링 실패: {e}")

# MFCC 추출
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

# 예측
def predict_cry(filename="temp_resampled.wav"):
    mfcc = extract_mfcc(filename)
    if mfcc is None:
        return
    model = joblib.load(MODEL_PATH)
    result = model.predict([mfcc])[0]
    prob = model.predict_proba([mfcc])[0][1]
    print(f"🍼 Result: {'Crying' if result == 1 else 'Not Crying'} (Cry probability: {prob:.3f})")

# 반복 실행
if __name__ == "__main__":
    while True:
        record_resample()
        predict_cry()
        time.sleep(1)
