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

@app.route("/detect", methods=["POST"])
def detect():
    try:
        # Check if frame is in request
        if "frame" not in request.files:
            return jsonify({"error": "No frame uploaded"}), 400

        # Read and validate image file
        file = request.files["frame"]
        if not file or file.filename == '':
            return jsonify({"error": "Empty file uploaded"}), 400

        # Read image data
        file_data = file.read()
        if len(file_data) == 0:
            return jsonify({"error": "Empty file data"}), 400

        # Convert to numpy array
        np_img = np.frombuffer(file_data, np.uint8)
        if np_img.size == 0:
            return jsonify({"error": "Invalid image data"}), 400

        # Decode image
        frame = cv2.imdecode(np_img, cv2.IMREAD_COLOR)
        
        # Check if decoding was successful
        if frame is None or frame.size == 0:
            return jsonify({"error": "Failed to decode image. Please check image format."}), 400

        # Additional validation - check if frame has proper dimensions
        if len(frame.shape) != 3 or frame.shape[2] != 3:
            return jsonify({"error": "Invalid image format. Expected RGB/BGR image."}), 400

        # Get expected prompt if provided
        expected_prompt = request.form.get('expected_prompt', None)

        # Process frame with error handling
        result = detector.process_frame(frame, expected_prompt)

        return jsonify({
            "success": True,
            "result": result,
            "frame_info": {
                "width": frame.shape[1],
                "height": frame.shape[0],
                "channels": frame.shape[2]
            }
        })

    except cv2.error as e:
        return jsonify({
            "success": False,
            "error": f"OpenCV error: {str(e)}",
            "suggestion": "Please check if the uploaded image is valid and not corrupted."
        }), 400
    
    except Exception as e:
        return jsonify({
            "success": False,
            "error": f"Processing error: {str(e)}"
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
        user_id = None
        
        # Check for video URL in JSON payload
        if request.is_json and 'video_url' in request.json:
            video_url = request.json['video_url']
            user_id = request.json.get('user_id')
            
            if not video_url:
                return jsonify({"error": "Empty video URL provided"}), 400
                
            # Download video from Supabase storage
            temp_filepath = download_video_from_url(video_url)
            
        # Fallback: Check for direct file upload (for backward compatibility)
        elif 'video' in request.files:
            file = request.files['video']
            user_id = request.form.get('user_id')
            
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
        pushup_count = result.get("pushups", 0)
        
        # Update database if user_id is provided
        if user_id and pushup_count > 0:
            try:
                update_result = supabase.table("profiles").update({
                    "pushups": int(pushup_count)
                }).eq("id", user_id).execute()
                
                if update_result.data:
                    result["database_updated"] = True
                    result["updated_user_id"] = user_id
                else:
                    result["database_updated"] = False
                    result["database_error"] = "User not found or update failed"
            except Exception as db_error:
                result["database_updated"] = False
                result["database_error"] = str(db_error)
        
        # Return result with consistent format for Flutter app
        return jsonify({
            "success": True,
            "count": pushup_count,
            "message": f"Analysis complete! Detected {pushup_count} push-ups.",
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
        user_id = None
        
        # Check for video URL in JSON payload
        if request.is_json and 'video_url' in request.json:
            video_url = request.json['video_url']
            user_id = request.json.get('user_id')
            
            if not video_url:
                return jsonify({"error": "Empty video URL provided"}), 400
                
            # Download video from Supabase storage
            temp_filepath = download_video_from_url(video_url)
            
        # Fallback: Check for direct file upload (for backward compatibility)
        elif 'video' in request.files:
            file = request.files['video']
            user_id = request.form.get('user_id')
            
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
        squat_count = result.get("squats", 0)
        
        # Update database if user_id is provided
        if user_id and squat_count > 0:
            try:
                update_result = supabase.table("profiles").update({
                    "squats": int(squat_count)
                }).eq("id", user_id).execute()
                
                if update_result.data:
                    result["database_updated"] = True
                    result["updated_user_id"] = user_id
                else:
                    result["database_updated"] = False
                    result["database_error"] = "User not found or update failed"
            except Exception as db_error:
                result["database_updated"] = False
                result["database_error"] = str(db_error)
        
        # Return result with consistent format for Flutter app
        return jsonify({
            "success": True,
            "count": squat_count,
            "message": f"Analysis complete! Detected {squat_count} squats.",
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
        user_id = None
        
        # Check for video URL in JSON payload
        if request.is_json and 'video_url' in request.json:
            video_url = request.json['video_url']
            exercise_type = request.json.get('exercise_type', 'pushups').lower()
            user_id = request.json.get('user_id')
            
            if not video_url:
                return jsonify({"error": "Empty video URL provided"}), 400
                
            if exercise_type not in ['pushups', 'squats']:
                return jsonify({"error": "Invalid exercise type. Use 'pushups' or 'squats'"}), 400
                
            # Download video from Supabase storage
            temp_filepath = download_video_from_url(video_url)
            
        # Fallback: Check for direct file upload (for backward compatibility)
        elif 'video' in request.files:
            exercise_type = request.form.get('exercise_type', 'pushups').lower()
            user_id = request.form.get('user_id')
            
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
            db_field = "pushups"
        else:  # squats
            result = squatsdoing(temp_filepath)
            count = result.get("squats", 0)
            db_field = "squats"
        
        # Update database if user_id is provided
        if user_id and count > 0:
            try:
                update_result = supabase.table("profiles").update({
                    db_field: int(count)
                }).eq("id", user_id).execute()
                
                if update_result.data:
                    result["database_updated"] = True
                    result["updated_user_id"] = user_id
                else:
                    result["database_updated"] = False
                    result["database_error"] = "User not found or update failed"
            except Exception as db_error:
                result["database_updated"] = False
                result["database_error"] = str(db_error)
            
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
            "detect": "/detect - POST with image file",
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