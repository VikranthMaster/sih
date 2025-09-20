import cv2
import mediapipe as mp
import random
import time
import numpy as np

class HandGestureDetector:
    def __init__(self):
        self.mp_hands = mp.solutions.hands
        self.hands = self.mp_hands.Hands(
            static_image_mode=False,  # Changed to False for real-time detection
            max_num_hands=2,
            min_detection_confidence=0.5,  # Lowered threshold for better detection
            min_tracking_confidence=0.5
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
        self.detection_count = 0  # Add counter for consistent detection

    def get_new_prompt(self):
        self.current_prompt = random.choice(self.prompts)
        self.wave_positions = []
        self.gesture_detected = False
        self.detection_count = 0
        print(f"New gesture: {self.current_prompt}")

    def is_finger_up(self, landmarks, finger_tip, finger_pip):
        """Check if a finger is pointing up"""
        return landmarks[finger_tip].y < landmarks[finger_pip].y

    def detect_wave(self, landmarks):
        """Detect waving motion - simplified for single frame detection"""
        wrist_x = landmarks[0].x
        current_time = time.time()
        
        # Add current position
        self.wave_positions.append((wrist_x, current_time))
        
        # Keep only recent positions (last 2 seconds)
        self.wave_positions = [(x, t) for x, t in self.wave_positions if current_time - t < 2.0]
        
        # Need at least 5 positions to detect wave
        if len(self.wave_positions) < 5:
            return False
            
        # Check for horizontal movement variation
        positions = [x for x, t in self.wave_positions]
        x_range = max(positions) - min(positions)
        
        # If hand is moving horizontally enough, consider it a wave
        return x_range > 0.1  # Adjust threshold as needed

    def detect_index_finger(self, landmarks):
        """Detect pointing with index finger"""
        try:
            # Index finger up
            index_up = self.is_finger_up(landmarks, 8, 6)
            # Other fingers down
            middle_down = not self.is_finger_up(landmarks, 12, 10)
            ring_down = not self.is_finger_up(landmarks, 16, 14)
            pinky_down = not self.is_finger_up(landmarks, 20, 18)
            
            # Thumb should be tucked (basic check)
            thumb_tucked = landmarks[4].y > landmarks[3].y
            
            return index_up and middle_down and ring_down and pinky_down and thumb_tucked
        except IndexError:
            return False

    def detect_fist(self, landmarks):
        """Detect closed fist"""
        try:
            # All fingers should be down
            fingers_down = [
                not self.is_finger_up(landmarks, 8, 6),   # Index
                not self.is_finger_up(landmarks, 12, 10), # Middle
                not self.is_finger_up(landmarks, 16, 14), # Ring
                not self.is_finger_up(landmarks, 20, 18), # Pinky
            ]
            
            # Thumb should be tucked in
            thumb_tucked = landmarks[4].x < landmarks[17].x  # Thumb tip vs hand center
            
            return all(fingers_down) and thumb_tucked
        except IndexError:
            return False

    def detect_open_hand(self, landmarks):
        """Detect open palm"""
        try:
            # All fingers should be up
            fingers_up = [
                self.is_finger_up(landmarks, 8, 6),   # Index
                self.is_finger_up(landmarks, 12, 10), # Middle
                self.is_finger_up(landmarks, 16, 14), # Ring
                self.is_finger_up(landmarks, 20, 18), # Pinky
            ]
            
            # Thumb should be extended
            thumb_up = landmarks[4].x > landmarks[3].x  # Basic thumb check
            
            return all(fingers_up) and thumb_up
        except IndexError:
            return False

    def detect_peace_sign(self, landmarks):
        """Detect peace sign (V shape with index and middle finger)"""
        try:
            # Index and middle fingers up
            index_up = self.is_finger_up(landmarks, 8, 6)
            middle_up = self.is_finger_up(landmarks, 12, 10)
            
            # Ring and pinky fingers down
            ring_down = not self.is_finger_up(landmarks, 16, 14)
            pinky_down = not self.is_finger_up(landmarks, 20, 18)
            
            # Check if fingers are spread apart (V shape)
            index_x = landmarks[8].x
            middle_x = landmarks[12].x
            finger_separation = abs(index_x - middle_x)
            
            return (index_up and middle_up and ring_down and 
                   pinky_down and finger_separation > 0.05)
        except IndexError:
            return False

    def check_gesture(self, landmarks):
        """Check if current gesture matches the prompt"""
        try:
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
        except Exception as e:
            print(f"Error in gesture detection: {e}")
            return False

    def process_frame(self, frame):
        """Process a single frame and return result"""
        try:
            # Validate frame
            if frame is None or frame.size == 0:
                return {
                    "gesture": self.current_prompt,
                    "detected": False,
                    "error": "Invalid frame"
                }
            
            # Convert BGR to RGB for MediaPipe
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            
            # Process the frame
            results = self.hands.process(frame_rgb)
            
            gesture_detected = False
            confidence = 0.0
            
            if results.multi_hand_landmarks:
                for hand_landmarks in results.multi_hand_landmarks:
                    if self.check_gesture(hand_landmarks.landmark):
                        gesture_detected = True
                        # Add confidence based on detection consistency
                        self.detection_count += 1
                        confidence = min(self.detection_count / 5.0, 1.0)  # Max confidence after 5 detections
                        break
            else:
                # Reset detection count if no hand detected
                self.detection_count = max(0, self.detection_count - 1)
                
            # Only return True if we have consistent detection
            final_detected = gesture_detected and confidence > 0.6
                
            return {
                "gesture": self.current_prompt,
                "detected": final_detected,
                "confidence": confidence,
                "hands_found": len(results.multi_hand_landmarks) if results.multi_hand_landmarks else 0
            }
            
        except Exception as e:
            return {
                "gesture": self.current_prompt,
                "detected": False,
                "error": f"Processing error: {str(e)}"
            }