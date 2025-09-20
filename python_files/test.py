import cv2
import mediapipe as mp
import random
import time

class HandGestureDetector:
    def __init__(self):
        self.mp_hands = mp.solutions.hands
        self.hands = self.mp_hands.Hands(
            static_image_mode=True,  # process single images
            max_num_hands=2,
            min_detection_confidence=0.7
        )
        self.mp_drawing = mp.solutions.drawing_utils
        
        self.prompts = [
            "Wave your hand",
            "Show your index finger",
            "Close your fist",
            "Open your hand",
            "Show peace sign (two fingers)"
        ]
        
        self.current_prompt = random.choice(self.prompts)
        self.wave_positions = []
        self.gesture_detected = False
        self.last_detection_time = 0

    def get_new_prompt(self):
        self.current_prompt = random.choice(self.prompts)
        self.wave_positions = []
        self.gesture_detected = False
        print(f"New gesture: {self.current_prompt}")

    def is_finger_up(self, landmarks, finger_tip, finger_pip):
        return landmarks[finger_tip].y < landmarks[finger_pip].y

    def detect_wave(self, landmarks):
        wrist_x = landmarks[0].x
        current_time = time.time()
        self.wave_positions.append((wrist_x, current_time))
        self.wave_positions = [(x, t) for x, t in self.wave_positions if current_time - t < 3.0]
        
        if len(self.wave_positions) < 10:
            return False
            
        positions = [x for x, t in self.wave_positions]
        movements = []
        for i in range(1, len(positions)):
            movements.append(1 if positions[i] > positions[i-1] else -1)
        
        direction_changes = sum(
            1 for i in range(1, len(movements)) if movements[i] != movements[i-1]
        )
        return direction_changes >= 4

    def detect_index_finger(self, landmarks):
        index_up = self.is_finger_up(landmarks, 8, 6)
        middle_down = not self.is_finger_up(landmarks, 12, 10)
        ring_down = not self.is_finger_up(landmarks, 16, 14)
        pinky_down = not self.is_finger_up(landmarks, 20, 18)
        return index_up and middle_down and ring_down and pinky_down

    def detect_fist(self, landmarks):
        fingers_down = [
            not self.is_finger_up(landmarks, 8, 6),
            not self.is_finger_up(landmarks, 12, 10),
            not self.is_finger_up(landmarks, 16, 14),
            not self.is_finger_up(landmarks, 20, 18),
        ]
        thumb_down = landmarks[4].x < landmarks[3].x
        return all(fingers_down) and thumb_down

    def detect_open_hand(self, landmarks):
        fingers_up = [
            self.is_finger_up(landmarks, 8, 6),
            self.is_finger_up(landmarks, 12, 10),
            self.is_finger_up(landmarks, 16, 14),
            self.is_finger_up(landmarks, 20, 18),
        ]
        thumb_up = landmarks[4].x > landmarks[3].x
        return all(fingers_up) and thumb_up

    def detect_peace_sign(self, landmarks):
        index_up = self.is_finger_up(landmarks, 8, 6)
        middle_up = self.is_finger_up(landmarks, 12, 10)
        ring_down = not self.is_finger_up(landmarks, 16, 14)
        pinky_down = not self.is_finger_up(landmarks, 20, 18)
        return index_up and middle_up and ring_down and pinky_down

    def check_gesture(self, landmarks):
        if self.current_prompt == "Wave your hand":
            return self.detect_wave(landmarks)
        elif self.current_prompt == "Show your index finger":
            return self.detect_index_finger(landmarks)
        elif self.current_prompt == "Close your fist":
            return self.detect_fist(landmarks)
        elif self.current_prompt == "Open your hand":
            return self.detect_open_hand(landmarks)
        elif self.current_prompt == "Show peace sign (two fingers)":
            return self.detect_peace_sign(landmarks)
        return False

    def process_frame(self, frame):
        """Process a single frame and return result"""
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = self.hands.process(frame_rgb)
        
        gesture_detected = False
        if results.multi_hand_landmarks:
            for hand_landmarks in results.multi_hand_landmarks:
                if self.check_gesture(hand_landmarks.landmark):
                    gesture_detected = True
                    break  # stop after first detected
                
        return {
            "gesture": self.current_prompt,
            "detected": gesture_detected
        }

