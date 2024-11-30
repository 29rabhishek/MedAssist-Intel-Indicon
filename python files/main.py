from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel
import numpy as np
import cv2
import requests
import os
from utils import detect_with_sliding_window, chk_med
from PIL import Image

app = FastAPI()

# Base URL for Ollama API
OLLAMA_API_BASE_URL = "http://127.0.0.1:11434/api"  # Change this if needed

# Input schema for the request body
class LlamaRequest(BaseModel):
    prompt: str

@app.post("/upload_file")
async def upload_image(file: UploadFile = File(...)):
    try:
        # Open and convert the uploaded image file to RGB format
        image = Image.open(file.file).convert('RGB')
        image_np = np.array(image)

        # Ensure uploads directory exists
        if not os.path.exists('uploads'):
            os.makedirs('uploads')

        # Save the image using OpenCV
        cv2.imwrite(f"uploads/{file.filename}", image_np)

        # Call your detection function
        predictions, img_stream = detect_with_sliding_window(image_np, step_size=64, window_size=(256, 128))
        
        # Process predictions with chk_med function
        predictions = chk_med(predictions)

        # Create a dynamic prompt for the LLM based on predictions
        dynamic_prompt = f"""Tell me about these medicines and their effects: {" ".join(predictions)}"""
        
        # Generate text using the dynamic prompt
        llm_response = await generate_text(LlamaRequest(prompt=dynamic_prompt))
        
        return {
            "predictions": llm_response['response'],
            "detected_words":predictions}
    
        # return StreamingResponse(
        #     img_stream, 
        #     media_type="image/png", 
        #     headers={"X-Detected-Texts": ", ".join(dynamic_prompt)}  # Optional custom headers
        #     )
    
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"detail": f"Failed to process image: {str(e)}"}
        )

@app.post("/generate")
async def generate_text(request: LlamaRequest):
    """
    Endpoint to generate text using Llama 3.
    """
    try:
        # Define the payload to send to the Ollama API
        payload = {
            "model": "monotykamary/medichat-llama3:latest",  # Replace with the appropriate model name if different
            "prompt": request.prompt,
            "stream": False,
            "options": {
                "num_ctx": 150
            }
        }
        
        # Make a POST request to the Ollama API
        response = requests.post(f"{OLLAMA_API_BASE_URL}/generate", json=payload)

        # Raise an exception if the request to Ollama API failed
        response.raise_for_status()

        # Return the generated text
        return response.json()

    except requests.exceptions.RequestException as e:
        # Handle errors during the request
        raise HTTPException(status_code=500, detail=f"Error calling Ollama API: {str(e)}")
