import os
import sys
import time
import fitz  # PyMuPDF
import requests
import json
import logging
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor, as_completed
import base64

# Set UTF-8 encoding for Windows
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

def setup_logger():
    logger = logging.getLogger("PDF_OCR")
    logger.setLevel(logging.ERROR)
    logger.handlers.clear()
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.ERROR)
    logger.addHandler(console_handler)
    return logger

logger = setup_logger()

def encode_image_to_base64(image_path):
    with open(image_path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")

def doubao_ocr_single_page(image_path, api_key, base_url):
    try:
        img_b64 = encode_image_to_base64(image_path)
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}"
        }
        prompt = "Please extract all text from the image, output as-is, maintain formatting, do not add explanations."
        data = {
            "model": "ark-code-latest",
            "messages": [{
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{img_b64}"}}
                ]
            }],
            "temperature": 0.0,
            "max_tokens": 8192
        }

        resp = requests.post(base_url, headers=headers, json=data, timeout=600)
        if resp.status_code != 200:
            return ""

        result = resp.json()
        return result["choices"][0]["message"]["content"].strip()
    except:
        return ""

def extract_pdf_text(pdf_path, api_key, base_url, start_page=1, end_page=0):
    import tempfile
    import shutil

    # Use system temporary directory
    temp_dir = tempfile.mkdtemp()

    doc = fitz.open(pdf_path)
    total_pages = len(doc)

    if end_page == 0 or end_page > total_pages:
        end_page = total_pages
    if start_page < 1:
        start_page = 1

    print(f"[INFO] PDF总页数: {total_pages}, 处理范围: 第{start_page}~{end_page}页")
    print("="*70)

    image_paths = []
    print("[INFO] 正在将PDF转换为高清图片...")
    for idx in range(start_page - 1, end_page):
        page = doc[idx]
        pix = page.get_pixmap(dpi=300)
        img_path = os.path.join(temp_dir, f"page_{idx+1:04d}.png")
        pix.save(img_path)
        image_paths.append(img_path)
        print(f"       第{idx+1}页转换完成")
    doc.close()

    all_text = ""
    success_count = 0
    fail_count = 0

    print("\n[INFO] 正在调用OCR识别文本...")
    with ThreadPoolExecutor(max_workers=3) as executor:
        futures = {executor.submit(doubao_ocr_single_page, p, api_key, base_url): p for p in image_paths}

        for future in as_completed(futures):
            img_path = futures[future]
            page_num = os.path.basename(img_path).split("_")[1].split(".")[0]

            try:
                txt = future.result()
                if txt and not txt.startswith("Error"):
                    success_count += 1
                    all_text += f"==================== PAGE {page_num} ====================\n{txt}\n\n"
                    print(f"       第{page_num}页识别成功 ({len(txt)}字符)")
                else:
                    fail_count += 1
                    print(f"       第{page_num}页识别失败")
            except Exception as e:
                fail_count += 1
                print(f"       第{page_num}页处理异常: {str(e)}")

    # Clean up temporary directory
    shutil.rmtree(temp_dir, ignore_errors=True)

    print("="*70)
    print(f"[INFO] 处理完成: 成功{success_count}页 | 失败{fail_count}页")
    return all_text

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python ocr_extract.py <pdf_path> [start_page] [end_page]")
        sys.exit(1)

    pdf_path = sys.argv[1]
    start_page = int(sys.argv[2]) if len(sys.argv) >=3 else 1
    end_page = int(sys.argv[3]) if len(sys.argv) >=4 else 0

    API_KEY = "YOUR_DOUBAO_API_KEY"
    BASE_URL = "https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions"

    text = extract_pdf_text(pdf_path, API_KEY, BASE_URL, start_page, end_page)
    print(text)
