import cv2
import mediapipe as mp
import random

class HandGestureDetector:
    def __init__(self):
        self.mp_hands = mp.solutions.hands
        self.hands = self.mp_hands.Hands(
            static_image_mode=False,
            max_num_hands=1,
            min_detection_confidence=0.7,
            min_tracking_confidence=0.5
        )
        
        # Available prompts
        self.prompts = [
            "Wave your hand",
            "Show your index finger", 
            "Close your fist",
            "Open your hand",
            "Show peace sign (two fingers)"
        ]
        self.current_prompt = random.choice(self.prompts)

    def get_new_prompt(self):
        """Get a new random prompt."""
        self.current_prompt = random.choice(self.prompts)
        return self.current_prompt

    def is_finger_up(self, landmarks, tip, pip):
        """Check if a finger is pointing up."""
        return landmarks[tip].y < landmarks[pip].y

    def detect_wave(self, landmarks):  
        # Simplified: hand open = wave placeholder
        return self.detect_open_hand(landmarks)

    def detect_index_finger(self, landmarks):
        """Detect pointing with index finger."""
        index_up = self.is_finger_up(landmarks, 8, 6)
        middle_down = not self.is_finger_up(landmarks, 12, 10)
        ring_down = not self.is_finger_up(landmarks, 16, 14)
        pinky_down = not self.is_finger_up(landmarks, 20, 18)
        return index_up and middle_down and ring_down and pinky_down

    def detect_fist(self, landmarks):
        """Detect closed fist."""
        fingers_down = [
            not self.is_finger_up(landmarks, 8, 6),   # Index
            not self.is_finger_up(landmarks, 12, 10), # Middle
            not self.is_finger_up(landmarks, 16, 14), # Ring
            not self.is_finger_up(landmarks, 20, 18), # Pinky
        ]
        # Check thumb position (more complex for fist detection)
        thumb_down = landmarks[4].x < landmarks[3].x if landmarks[4].x < landmarks[0].x else landmarks[4].x > landmarks[3].x
        return all(fingers_down) and thumb_down

    def detect_open_hand(self, landmarks):
        """Detect open palm."""
        fingers_up = [
            self.is_finger_up(landmarks, 8, 6),   # Index
            self.is_finger_up(landmarks, 12, 10), # Middle  
            self.is_finger_up(landmarks, 16, 14), # Ring
            self.is_finger_up(landmarks, 20, 18), # Pinky
        ]
        # Check thumb (different logic based on hand orientation)
        thumb_up = landmarks[4].x > landmarks[3].x
        return sum(fingers_up) >= 3 and thumb_up  # At least 3 fingers + thumb

    def detect_peace_sign(self, landmarks):
        """Detect peace sign (V with index and middle finger)."""
        index_up = self.is_finger_up(landmarks, 8, 6)
        middle_up = self.is_finger_up(landmarks, 12, 10)
        ring_down = not self.is_finger_up(landmarks, 16, 14)
        pinky_down = not self.is_finger_up(landmarks, 20, 18)
        return index_up and middle_up and ring_down and pinky_down

    def classify_gesture(self, landmarks):
        """Classify the detected hand gesture."""
        try:
            if self.detect_fist(landmarks):
                return "Close your fist"
            elif self.detect_peace_sign(landmarks):
                return "Show peace sign (two fingers)"
            elif self.detect_index_finger(landmarks):
                return "Show your index finger"
            elif self.detect_open_hand(landmarks):
                return "Open your hand"
            elif self.detect_wave(landmarks):
                return "Wave your hand"
            else:
                return "Unknown gesture"
        except Exception as e:
            print(f"Error in gesture classification: {e}")
            return "Error detecting gesture"

    def process_frame(self, frame, expected_prompt=None):
        """Process a frame and detect hand gestures."""
        try:
            # Validate frame
            if frame is None or frame.size == 0:
                return {
                    "gesture": "No frame",
                    "expected_prompt": expected_prompt,
                    "detected": False,
                    "error": "Empty or invalid frame"
                }

            # Check frame dimensions
            if len(frame.shape) != 3 or frame.shape[2] != 3:
                return {
                    "gesture": "Invalid frame",
                    "expected_prompt": expected_prompt,
                    "detected": False,
                    "error": "Frame must be a 3-channel (RGB/BGR) image"
                }

            # Convert BGR to RGB for MediaPipe
            image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            
            # Process with MediaPipe
            results = self.hands.process(image_rgb)

            # Check if hands are detected
            if results.multi_hand_landmarks:
                for hand_landmarks in results.multi_hand_landmarks:
                    gesture = self.classify_gesture(hand_landmarks.landmark)
                    
                    # Check if gesture matches expected prompt
                    matched = (expected_prompt is not None and gesture == expected_prompt)
                    
                    return {
                        "gesture": gesture,
                        "expected_prompt": expected_prompt or self.current_prompt,
                        "detected": matched if expected_prompt else True,
                        "confidence": "high",  # You could add actual confidence scoring
                        "hand_detected": True
                    }

            # No hands detected
            return {
                "gesture": "No hand detected",
                "expected_prompt": expected_prompt or self.current_prompt,
                "detected": False,
                "hand_detected": False
            }

        except cv2.error as e:
            return {
                "gesture": "OpenCV Error",
                "expected_prompt": expected_prompt,
                "detected": False,
                "error": f"OpenCV error: {str(e)}",
                "hand_detected": False
            }
        except Exception as e:
            return {
                "gesture": "Processing Error", 
                "expected_prompt": expected_prompt,
                "detected": False,
                "error": f"Unexpected error: {str(e)}",
                "hand_detected": False
            }