import os
import numpy as np
import librosa
from sklearn.model_selection import train_test_split
from sklearn.neighbors import KNeighborsClassifier
import joblib

# 설정
CRY_DIR = "/home/pi/inno_2/cry/cry_data"
NONCRY_DIR = "/home/pi/inno_2/cry/noncry_data"
SR = 16000
DURATION = 2.0
N_MFCC = 13
MAX_LEN = 40
MODEL_PATH = "knn_model.joblib"

def extract_mfcc(file_path):
    try:
        y, sr = librosa.load(file_path, sr=SR, duration=DURATION)
        mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=N_MFCC)
        if mfcc.shape[1] < MAX_LEN:
            pad = MAX_LEN - mfcc.shape[1]
            mfcc = np.pad(mfcc, ((0, 0), (0, pad)), mode='constant')
        else:
            mfcc = mfcc[:, :MAX_LEN]
        return mfcc.flatten()
    except Exception as e:
        print(f"[ERROR] {file_path}: {e}")
        return None

# 데이터 불러오기
X, y = [], []
for label, folder in enumerate([NONCRY_DIR, CRY_DIR]):
    for fname in os.listdir(folder):
        if fname.endswith(".wav"):
            path = os.path.join(folder, fname)
            features = extract_mfcc(path)
            if features is not None:
                X.append(features)
                y.append(label)

X = np.array(X)
y = np.array(y)

# 학습
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
knn = KNeighborsClassifier(n_neighbors=3)
knn.fit(X_train, y_train)

# 정확도 출력
print(f"✅ Test Accuracy: {knn.score(X_test, y_test):.2f}")

# 모델 저장
joblib.dump(knn, MODEL_PATH)
print(f"📦 모델 저장 완료: {MODEL_PATH}")
