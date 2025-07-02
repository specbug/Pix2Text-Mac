#!/usr/bin/env python3
"""
Bridge script for SwiftUI Pix2Text app to call Python Pix2Text functionality
"""

import sys
import json
import yaml
from pathlib import Path
from PIL import ImageGrab, Image
from pix2text import Pix2Text


def load_config():
    """Load configuration from config.yaml"""
    try:
        config_path = Path(__file__).parent / "config.yaml"
        with open(config_path, "r", encoding="utf-8") as f:
            return yaml.safe_load(f)
    except Exception as e:
        return {"pix2text": {}, "text_formula_resized_shape": 608}


def process_clipboard_image():
    """Process image from clipboard and return LaTeX"""
    try:
        # Get image from clipboard
        image = ImageGrab.grabclipboard()
        if image is None:
            return {"error": "No image found in clipboard"}

        # Load config and initialize Pix2Text
        config = load_config()
        p2t = Pix2Text.from_config(**config.get("pix2text", {}))

        # Process the image
        resized_shape = config.get("text_formula_resized_shape", 608)
        latex_result = p2t.recognize_text_formula(
            image, resized_shape=resized_shape, return_text=True
        )

        return {"success": True, "latex": latex_result}

    except Exception as e:
        return {"error": str(e)}


def process_image_file(image_path):
    """Process image file and return LaTeX"""
    try:
        # Load and process image
        image = Image.open(image_path)

        # Load config and initialize Pix2Text
        config = load_config()
        p2t = Pix2Text.from_config(**config.get("pix2text", {}))

        # Process the image
        resized_shape = config.get("text_formula_resized_shape", 608)
        latex_result = p2t.recognize_text_formula(
            image, resized_shape=resized_shape, return_text=True
        )

        return {"success": True, "latex": latex_result}

    except Exception as e:
        return {"error": str(e)}


def main():
    """Main function to handle command line arguments"""
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No command specified"}))
        sys.exit(1)

    command = sys.argv[1]

    if command == "clipboard":
        result = process_clipboard_image()
    elif command == "file" and len(sys.argv) > 2:
        image_path = sys.argv[2]
        result = process_image_file(image_path)
    else:
        result = {"error": f"Unknown command: {command}"}

    # Output JSON result
    print(json.dumps(result))


if __name__ == "__main__":
    main()
