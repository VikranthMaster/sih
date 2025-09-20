from flask import Flask, request, jsonify
import cv2
import numpy as np
import base64
import os
import requests
from python_files.test import HandGestureDetector
from werkzeug.utils import secure_filename
from python_files.push import pushup
from python_files.sqats import squatsdoing
from urllib.parse import urlparse
import tempfile
from supabase import create_client

app = Flask(__name__)
SUPABASE_URL="https://dbxaqntkbcbypbwkuwti.supabase.co"
SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRieGFxbnRrYmNieXBid2t1d3RpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODI5MTY3MiwiZXhwIjoyMDczODY3NjcyfQ.372-VGu6FSPT_S7czhZGm2yRZmKo6lYSlp5R_Nmmd68"
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
# Initialize detector
detector = HandGestureDetector()

# Configuration
UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'mp4', 'avi', 'mov', 'mkv'}
MAX_CONTENT_LENGTH = 100 * 1024 * 1024  # 100MB max file size

# Create upload folder if it doesn't exist
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Configure Flask
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = MAX_CONTENT_LENGTH

def download_video_from_url(video_url, max_size_mb=100):
    """Download video from URL (Supabase storage) and save temporarily."""
    try:
        # Validate URL
        parsed_url = urlparse(video_url)
        if not parsed_url.scheme or not parsed_url.netloc:
            raise ValueError("Invalid video URL")
        
        # Download video with streaming
        response = requests.get(video_url, stream=True, timeout=30)
        response.raise_for_status()
        
        # Check content length
        content_length = response.headers.get('content-length')
        if content_length and int(content_length) > max_size_mb * 1024 * 1024:
            raise ValueError(f"Video file too large. Maximum size is {max_size_mb}MB")
        
        # Create temporary file
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix='.mp4')
        
        # Download and save
        total_size = 0
        for chunk in response.iter_content(chunk_size=8192):
            if chunk:
                total_size += len(chunk)
                if total_size > max_size_mb * 1024 * 1024:
                    temp_file.close()
                    os.unlink(temp_file.name)
                    raise ValueError(f"Video file too large. Maximum size is {max_size_mb}MB")
                temp_file.write(chunk)
        
        temp_file.close()
        return temp_file.name
        
    except requests.exceptions.RequestException as e:
        raise Exception(f"Failed to download video: {str(e)}")
    except Exception as e:
        raise Exception(f"Error processing video URL: {str(e)}")

def allowed_file(filename):
    """Check if the uploaded file has an allowed extension."""
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route("/", methods=["POST", "GET"])
def home():
    return jsonify({"go":"Working"}), 202

@app.route('/detect', methods=['POST'])
def detect():
    """Hand gesture detection endpoint."""
    try:
        # Check if request has JSON data
        if not request.is_json:
            return jsonify({"error": "Request must contain JSON data"}), 400
            
        # Check if image data is provided
        if 'image' not in request.json:
            return jsonify({"error": "No image data provided"}), 400
            
        # Get base64 image data
        image_data = request.json['image']
        
        if not image_data:
            return jsonify({"error": "Empty image data"}), 400
            
        try:
            # Decode base64 image
            image_bytes = base64.b64decode(image_data)
            nparr = np.frombuffer(image_bytes, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if frame is None:
                return jsonify({"error": "Could not decode image data"}), 400
                
        except Exception as decode_error:
            return jsonify({"error": f"Image decoding failed: {str(decode_error)}"}), 400
        
        # Process the frame with gesture detector
        result = detector.process_frame(frame)
        
        # Add debug info if there's an error
        if "error" in result:
            print(f"Detection error: {result['error']}")
            
        # Return success response
        return jsonify(result), 200
        
    except Exception as e:
        error_msg = f"Detection failed: {str(e)}"
        print(f"Server error: {error_msg}")
        return jsonify({
            "error": error_msg,
            "gesture": detector.current_prompt if detector else "unknown",
            "detected": False
        }), 500

@app.route('/detect_debug', methods=['POST'])
def detect_debug():
    """Debug version of detect endpoint with more detailed logging."""
    try:
        print("=== DEBUG: /detect_debug called ===")
        
        # Log request info
        print(f"Content-Type: {request.headers.get('Content-Type')}")
        print(f"Request is JSON: {request.is_json}")
        
        if not request.is_json:
            return jsonify({"error": "Request must contain JSON data"}), 400
            
        # Check image data
        if 'image' not in request.json:
            print("ERROR: No 'image' key in request")
            return jsonify({"error": "No image data provided"}), 400
            
        image_data = request.json['image']
        print(f"Image data length: {len(image_data) if image_data else 0}")
        
        if not image_data:
            return jsonify({"error": "Empty image data"}), 400
        
        # Decode and process
        try:
            image_bytes = base64.b64decode(image_data)
            print(f"Decoded bytes length: {len(image_bytes)}")
            
            nparr = np.frombuffer(image_bytes, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if frame is None:
                print("ERROR: cv2.imdecode returned None")
                return jsonify({"error": "Could not decode image"}), 400
                
            print(f"Frame shape: {frame.shape}")
            
        except Exception as decode_error:
            print(f"Decode error: {decode_error}")
            return jsonify({"error": f"Decoding failed: {str(decode_error)}"}), 400
        
        # Process with detector
        print(f"Current prompt: {detector.current_prompt}")
        result = detector.process_frame(frame)
        print(f"Detection result: {result}")
        
        return jsonify(result), 200
        
    except Exception as e:
        error_msg = f"Debug detection failed: {str(e)}"
        print(f"DEBUG ERROR: {error_msg}")
        return jsonify({
            "error": error_msg,
            "detected": False
        }), 500

@app.route('/test_detector', methods=['GET'])
def test_detector():
    """Test if the gesture detector is working."""
    try:
        # Create a simple test image (white background)
        test_frame = np.ones((480, 640, 3), dtype=np.uint8) * 255
        
        # Process with detector
        result = detector.process_frame(test_frame)
        
        return jsonify({
            "detector_status": "working",
            "current_prompt": detector.current_prompt,
            "test_result": result,
            "available_prompts": detector.prompts
        }), 200
        
    except Exception as e:
        return jsonify({
            "detector_status": "error",
            "error": str(e)
        }), 500

@app.route('/new_prompt', methods=['GET'])
def new_prompt():
    """Get a new prompt for hand gesture detection."""
    try:
        detector.get_new_prompt()
        return jsonify({"new_prompt": detector.current_prompt})
    except Exception as e:
        return jsonify({"error": f"Failed to get new prompt: {str(e)}"}), 500

@app.route('/pushups', methods=['POST'])
def pushups():
    """Push-up counting endpoint - accepts video URL from Supabase storage."""
    temp_filepath = None
    try:
        # Check for video URL in JSON payload
        if request.is_json and 'video_url' in request.json:
            video_url = request.json['video_url']
            if not video_url:
                return jsonify({"error": "Empty video URL provided"}), 400
                
            # Download video from Supabase storage
            temp_filepath = download_video_from_url(video_url)
            
        # Fallback: Check for direct file upload (for backward compatibility)
        elif 'video' in request.files:
            file = request.files['video']
            
            if file.filename == '':
                return jsonify({"error": "No video file selected"}), 400

            if not allowed_file(file.filename):
                return jsonify({
                    "error": "Invalid file type. Allowed types: mp4, avi, mov, mkv"
                }), 400

            # Save uploaded file temporarily
            filename = secure_filename(file.filename) or "video.mp4"
            temp_filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(temp_filepath)
            
        else:
            return jsonify({"error": "No video URL or file provided"}), 400

        # Process the video and count push-ups
        result = pushup(temp_filepath)
        
        # update = supabase.table("profiles").update({"pushups": int(result['pushups'])}).eq("full_name", ).execute()
        
        # Return result with consistent format for Flutter app
        return jsonify({
            "success": True,
            "count": result.get("pushups", 0),
            "message": f"Analysis complete! Detected {result.get('pushups', 0)} push-ups.",
            "details": result
        })
        
    except Exception as e:
        return jsonify({
            "success": False,
            "error": f"Push-up analysis failed: {str(e)}",
            "count": 0
        }), 500
    finally:
        # Clean up temporary file
        if temp_filepath and os.path.exists(temp_filepath):
            try:
                os.remove(temp_filepath)
            except OSError:
                pass

@app.route('/squats', methods=['POST'])
def squats():
    """Squat counting endpoint - accepts video URL from Supabase storage."""
    temp_filepath = None
    try:
        # Check for video URL in JSON payload
        if request.is_json and 'video_url' in request.json:
            video_url = request.json['video_url']
            if not video_url:
                return jsonify({"error": "Empty video URL provided"}), 400
                
            # Download video from Supabase storage
            temp_filepath = download_video_from_url(video_url)
            
        # Fallback: Check for direct file upload (for backward compatibility)
        elif 'video' in request.files:
            file = request.files['video']
            
            if file.filename == '':
                return jsonify({"error": "No video file selected"}), 400

            if not allowed_file(file.filename):
                return jsonify({
                    "error": "Invalid file type. Allowed types: mp4, avi, mov, mkv"
                }), 400

            # Save uploaded file temporarily
            filename = secure_filename(file.filename) or "video.mp4"
            temp_filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(temp_filepath)
            
        else:
            return jsonify({"error": "No video URL or file provided"}), 400

        # Process the video and count squats
        result = squatsdoing(temp_filepath)
        
        
        # Return result with consistent format for Flutter app
        return jsonify({
            "success": True,
            "count": result.get("squats", 0),
            "message": f"Analysis complete! Detected {result.get('squats', 0)} squats.",
            "details": result
        })
        
    except Exception as e:
        return jsonify({
            "success": False,
            "error": f"Squat analysis failed: {str(e)}",
            "count": 0
        }), 500
    finally:
        # Clean up temporary file
        if temp_filepath and os.path.exists(temp_filepath):
            try:
                os.remove(temp_filepath)
            except OSError:
                pass

@app.route('/analyze', methods=['POST'])
def analyze_video():
    """General video analysis endpoint that can handle both push-ups and squats."""
    temp_filepath = None
    try:
        exercise_type = 'pushups'  # Default
        
        # Check for video URL in JSON payload
        if request.is_json and 'video_url' in request.json:
            video_url = request.json['video_url']
            exercise_type = request.json.get('exercise_type', 'pushups').lower()
            
            if not video_url:
                return jsonify({"error": "Empty video URL provided"}), 400
                
            if exercise_type not in ['pushups', 'squats']:
                return jsonify({"error": "Invalid exercise type. Use 'pushups' or 'squats'"}), 400
                
            # Download video from Supabase storage
            temp_filepath = download_video_from_url(video_url)
            
        # Fallback: Check for direct file upload (for backward compatibility)
        elif 'video' in request.files:
            exercise_type = request.form.get('exercise_type', 'pushups').lower()
            
            if exercise_type not in ['pushups', 'squats']:
                return jsonify({"error": "Invalid exercise type. Use 'pushups' or 'squats'"}), 400

            file = request.files['video']
            
            if file.filename == '':
                return jsonify({"error": "No video file selected"}), 400

            if not allowed_file(file.filename):
                return jsonify({
                    "error": "Invalid file type. Allowed types: mp4, avi, mov, mkv"
                }), 400

            # Save uploaded file temporarily
            filename = secure_filename(file.filename) or f"{exercise_type}_video.mp4"
            temp_filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(temp_filepath)
            
        else:
            return jsonify({"error": "No video URL or file provided"}), 400

        # Process based on exercise type
        if exercise_type == 'pushups':
            result = pushup(temp_filepath)
            count = result.get("pushups", 0)
        else:  # squats
            result = squatsdoing(temp_filepath)
            count = result.get("squats", 0)
            
        # Return comprehensive result
        return jsonify({
            "success": True,
            "exercise_type": exercise_type,
            "count": count,
            "message": f"Analysis complete! Detected {count} {exercise_type}.",
            "details": result
        })
        
    except Exception as e:
        return jsonify({
            "success": False,
            "error": f"Video analysis failed: {str(e)}",
            "count": 0
        }), 500
    finally:
        # Clean up temporary file
        if temp_filepath and os.path.exists(temp_filepath):
            try:
                os.remove(temp_filepath)
            except OSError:
                pass

@app.route('/health', methods=['GET'])
def health_check():
    """Simple health check endpoint."""
    return jsonify({
        "status": "healthy",
        "message": "Fitness tracking server is running",
        "endpoints": {
            "pushups": "/pushups - POST with video_url (JSON) or video file",
            "squats": "/squats - POST with video_url (JSON) or video file", 
            "analyze": "/analyze - POST with video_url and exercise_type (JSON) or video file",
            "detect": "/detect - POST with base64 image",
            "new_prompt": "/new_prompt - GET"
        },
        "supported_methods": {
            "supabase_storage": "Send JSON with 'video_url' field",
            "direct_upload": "Send multipart form with 'video' file (fallback)"
        }
    })

@app.errorhandler(413)
def too_large(e):
    """Handle file too large errors."""
    return jsonify({
        "error": "File too large. Maximum size is 100MB."
    }), 413

@app.errorhandler(500)
def internal_error(error):
    """Handle internal server errors."""
    return jsonify({
        "error": "Internal server error occurred."
    }), 500

if __name__ == "__main__":
    print("Starting Fitness Tracking Server...")
    print(f"Upload folder: {UPLOAD_FOLDER}")
    print(f"Max file size: {MAX_CONTENT_LENGTH // (1024*1024)}MB")
    print("Available endpoints:")
    print("  POST /pushups - Upload video for push-up counting")
    print("  POST /squats - Upload video for squat counting")
    print("  POST /analyze - General video analysis")
    print("  POST /detect - Hand gesture detection")
    print("  GET /new_prompt - Get new gesture prompt")
    print("  GET /health - Health check")
    
    app.run(debug=True, host='0.0.0.0', port=5000)