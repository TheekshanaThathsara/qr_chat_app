#!/usr/bin/env python3
"""
Create QR CHAT logo matching the provided design
"""
from PIL import Image, ImageDraw, ImageFont
import os

def create_qr_chat_logo():
    # Create a 512x512 image with orange gradient background
    size = 512
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # Orange gradient colors (matching the provided design)
    orange_color = (255, 152, 0)  # #FF9800
    
    # Fill with solid orange background
    draw.rectangle([(0, 0), (size, size)], fill=orange_color)
    
    # Try to use a bold font, fallback to default if not available
    try:
        # Try to find a bold system font
        font_large = ImageFont.truetype("/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf", 120)
        font_small = ImageFont.truetype("/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf", 80)
    except:
        try:
            font_large = ImageFont.truetype("arial.ttf", 120)
            font_small = ImageFont.truetype("arial.ttf", 80)
        except:
            # Fallback to default font
            font_large = ImageFont.load_default()
            font_small = ImageFont.load_default()
    
    # Text color (white)
    text_color = (255, 255, 255)
    
    # Draw "QR" text
    qr_text = "QR"
    qr_bbox = draw.textbbox((0, 0), qr_text, font=font_large)
    qr_width = qr_bbox[2] - qr_bbox[0]
    qr_height = qr_bbox[3] - qr_bbox[1]
    qr_x = (size - qr_width) // 2
    qr_y = size // 2 - qr_height - 20
    
    draw.text((qr_x, qr_y), qr_text, fill=text_color, font=font_large)
    
    # Draw "CHAT" text
    chat_text = "CHAT"
    chat_bbox = draw.textbbox((0, 0), chat_text, font=font_small)
    chat_width = chat_bbox[2] - chat_bbox[0]
    chat_height = chat_bbox[3] - chat_bbox[1]
    chat_x = (size - chat_width) // 2
    chat_y = size // 2 + 20
    
    draw.text((chat_x, chat_y), chat_text, fill=text_color, font=font_small)
    
    # Save the image
    output_path = "assets/images/qr_chat_logo.png"
    image.save(output_path, "PNG", quality=95)
    print(f"Logo saved to {output_path}")
    
    # Also create a smaller version for better mobile performance
    small_image = image.resize((256, 256), Image.Resampling.LANCZOS)
    small_output_path = "assets/images/qr_chat_logo_small.png"
    small_image.save(small_output_path, "PNG", quality=95)
    print(f"Small logo saved to {small_output_path}")

if __name__ == "__main__":
    create_qr_chat_logo()
