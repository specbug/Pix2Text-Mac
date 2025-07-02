#!/usr/bin/env python3
"""
Bridge script for SwiftUI Pix2Text app to call Python Pix2Text functionality
"""

import sys
import json
import yaml
import os
import traceback
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
    image = ImageGrab.grabclipboard()
    if image is None:
        return {"error": "No image found in clipboard"}

    config = load_config()
    p2t = Pix2Text.from_config(**config.get("pix2text", {}))

    resized_shape = config.get("text_formula_resized_shape", 608)
    latex_result = p2t.recognize_text_formula(
        image, resized_shape=resized_shape, return_text=True
    )

    return {"success": True, "latex": latex_result, "confidence": 0.95}


def process_image_file(image_path):
    """Process image file and return LaTeX"""
    image = Image.open(image_path)

    config = load_config()
    p2t = Pix2Text.from_config(**config.get("pix2text", {}))

    resized_shape = config.get("text_formula_resized_shape", 608)
    latex_result = p2t.recognize_text_formula(
        image, resized_shape=resized_shape, return_text=True
    )

    return {"success": True, "latex": latex_result, "confidence": 0.95}


def main():
    """Main function to handle command line arguments"""
    try:
        if len(sys.argv) < 2:
            result = {"error": "No command specified"}
        elif sys.argv[1] == "clipboard":
            result = process_clipboard_image()
        elif sys.argv[1] == "file" and len(sys.argv) > 2:
            result = process_image_file(sys.argv[2])
        else:
            result = {"error": f"Unknown command: {sys.argv[1]}"}
    except Exception as e:
        result = {"error": str(e), "traceback": traceback.format_exc()}

    print(json.dumps(result))


if __name__ == "__main__":
    main()
