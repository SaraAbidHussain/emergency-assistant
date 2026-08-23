import os
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()

print("Key loaded:", os.getenv("BAILIAN_API_KEY")[:10] if os.getenv("BAILIAN_API_KEY") else "NOT FOUND")

client = OpenAI(
    api_key=os.getenv("BAILIAN_API_KEY"),
    base_url="https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
)

try:
    response = client.chat.completions.create(
        model="qwen-plus-character",
        messages=[
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "Who are you?"}
        ]
    )
    print("SUCCESS:", response.choices[0].message.content)
except Exception as e:
    print("ERROR TYPE:", type(e).__name__)
    print("ERROR MESSAGE:", str(e))