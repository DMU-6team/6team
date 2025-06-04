import cv2

cap = cv2.VideoCapture(0)
if cap.isOpened():
    print("✅ 카메라 열림 성공")
else:
    print("❌ 카메라 열기 실패")

cap.release()
