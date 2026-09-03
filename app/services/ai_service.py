"""
ai_service.py
Qwen (Alibaba Cloud Model Studio) integration for emergency classification
and first-aid question generation.
"""

import os
import json
import re
from typing import Optional

from openai import OpenAI
from pydantic import BaseModel, ValidationError, Field
from dotenv import load_dotenv
load_dotenv()
# ---------------------------------------------------------------------------
# Client setup
# ---------------------------------------------------------------------------

client = OpenAI(
    api_key=os.getenv("BAILIAN_API_KEY"),
    base_url="https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
)

MODEL_NAME = "qwen-plus-character"

VALID_EMERGENCY_TYPES = ["injury", "personal_safety", "fire", "earthquake"]


# ---------------------------------------------------------------------------
# Schemas (Pydantic) — matches CONTRACT.md
# ---------------------------------------------------------------------------

class ClassificationResult(BaseModel):
    emergency_type: str = Field(...)
    severity_hint: int = Field(..., ge=1, le=4)
    confidence: float = Field(..., ge=0.0, le=1.0)
    reasoning: str = Field(...)

    def model_post_init(self, __context) -> None:
        if self.emergency_type not in VALID_EMERGENCY_TYPES:
            raise ValueError(
                f"emergency_type must be one of {VALID_EMERGENCY_TYPES}, got {self.emergency_type}"
            )


class FirstAidQuestion(BaseModel):
    question: str
    options: list[str]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _strip_code_fences(text: str) -> str:
    """Remove ```json ... ``` or ``` ... ``` wrappers if the model adds them."""
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```$", "", text)
    return text.strip()


def _safe_default_classification() -> dict:
    return {
        "emergency_type": "injury",
        "severity_hint": 3,
        "confidence": 0.0,
        "reasoning": "Fallback default — AI classification failed or was unavailable.",
    }


# ---------------------------------------------------------------------------
# 3.1 + 3.2 — classify_emergency()
# ---------------------------------------------------------------------------

CLASSIFY_SYSTEM_PROMPT = """You are an emergency triage classifier for a safety app.
Given a short description of a situation (which may be in English, Roman Urdu, or a mix of both),
classify it and respond with ONLY a valid JSON object — no extra text, no markdown, no code fences.

The JSON object must have exactly these fields:
{
  "emergency_type": one of ["injury", "personal_safety", "fire", "earthquake"],
  "severity_hint": an integer from 1 (minor) to 4 (life-threatening),
  "confidence": a float from 0.0 to 1.0 representing your confidence in this classification,
  "reasoning": a short one-sentence explanation in English
}

Rules:
- Always respond in English for emergency_type and reasoning, even if the input is in Roman Urdu or mixed language.
- Roman Urdu examples: "Mujhe saans lene mein mushkil ho rahi hai" (I'm having trouble breathing) -> likely injury, high severity.
  "Ghar mein aag lag gayi hai" (There's a fire in the house) -> fire.
  "Koi mera peecha kar raha hai" (Someone is following me) -> personal_safety.
- If unsure, choose the closest matching category and lower your confidence score accordingly.
- Do not include any text outside the JSON object.
"""

CLASSIFY_STRICT_RETRY_SUFFIX = """
IMPORTANT: Your previous response was not valid JSON matching the required schema.
Respond with ONLY the raw JSON object. No markdown formatting, no code fences, no explanation text
before or after the JSON. Just the JSON object itself, starting with { and ending with }.
"""


def _call_qwen_classify(description: str, strict: bool = False) -> str:
    system_prompt = CLASSIFY_SYSTEM_PROMPT
    if strict:
        system_prompt += CLASSIFY_STRICT_RETRY_SUFFIX

    kwargs = dict(
        model=MODEL_NAME,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": description},
        ],
        temperature=0.2,
    )

    try:
        response = client.chat.completions.create(
            response_format={"type": "json_object"},
            **kwargs,
        )
    except Exception:
        # response_format not supported / rejected — retry without it
        response = client.chat.completions.create(**kwargs)

    return response.choices[0].message.content


def classify_emergency(description: str) -> dict:
    """
    Classify an emergency description into type, severity, confidence, and reasoning.
    Always returns a dict matching CONTRACT.md's /emergency/classify response shape.
    Never raises — falls back to a safe default on any failure.
    """
    for attempt, strict in enumerate([False, True]):
        try:
            raw = _call_qwen_classify(description, strict=strict)
            cleaned = _strip_code_fences(raw)
            parsed = json.loads(cleaned)
            result = ClassificationResult(**parsed)
            return result.model_dump()
        except (json.JSONDecodeError, ValidationError, Exception) as e:
            if attempt == 0:
                # retry once with a stricter prompt
                continue
            else:
                # both attempts failed — safe fallback, never crash
                return _safe_default_classification()

    return _safe_default_classification()


# ---------------------------------------------------------------------------
# 3.3 — get_first_aid_question()
# ---------------------------------------------------------------------------

FIRST_AID_SYSTEM_PROMPT = """You are a first-aid guidance assistant embedded in an emergency response app.
Your ONLY job is to ask ONE short, simple yes/no/unsure question at a time to help assess the situation.

Strict rules:
- Ask exactly ONE question per response.
- Keep the question short and simple (under 15 words), understandable in a stressful situation.
- NEVER make a diagnosis or claim to know what is medically wrong with the person.
- NEVER give treatment instructions yourself — your job is only to ask the next assessment question.
- Always defer serious concerns to professional emergency responders; do not suggest this app replaces them.
- Base the next question on the emergency_type and the conversation so far (previous_answers).
- Respond with ONLY a valid JSON object, no markdown, no extra text:
{
  "question": "string",
  "options": ["Yes", "No", "Unsure"]
}
"""


def get_first_aid_question(emergency_type: str, previous_answers: list[dict]) -> dict:
    """
    Ask Qwen for the next single first-aid assessment question given the
    emergency type and the conversation so far.

    previous_answers: list of {"question": str, "answer": str} dicts.
    Returns {"question": str, "options": ["Yes","No","Unsure"]}.
    Falls back to a safe generic question if the call fails.
    """
    conversation_summary = json.dumps(previous_answers, ensure_ascii=False)
    user_content = (
        f"emergency_type: {emergency_type}\n"
        f"previous_answers: {conversation_summary}\n\n"
        "What is the next single assessment question to ask?"
    )

    for attempt, strict in enumerate([False, True]):
        try:
            system_prompt = FIRST_AID_SYSTEM_PROMPT
            if strict:
                system_prompt += "\nRespond with ONLY the raw JSON object, nothing else."

            kwargs = dict(
                model=MODEL_NAME,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_content},
                ],
                temperature=0.3,
            )
            try:
                response = client.chat.completions.create(
                    response_format={"type": "json_object"},
                    **kwargs,
                )
            except Exception:
                response = client.chat.completions.create(**kwargs)

            raw = response.choices[0].message.content
            cleaned = _strip_code_fences(raw)
            parsed = json.loads(cleaned)
            result = FirstAidQuestion(**parsed)
            return result.model_dump()
        except (json.JSONDecodeError, ValidationError, Exception):
            if attempt == 0:
                continue
            else:
                return {
                    "question": "Is the person conscious?",
                    "options": ["Yes", "No", "Unsure"],
                }

    return {
        "question": "Is the person conscious?",
        "options": ["Yes", "No", "Unsure"],
    }


# ---------------------------------------------------------------------------
# Test script (run: python ai_service.py)
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print("=== Test 1: classify_emergency (English) ===")
    result1 = classify_emergency("I fell from the stairs and my leg is bleeding badly")
    print(json.dumps(result1, indent=2))

    print("\n=== Test 2: classify_emergency (Roman Urdu) ===")
    result2 = classify_emergency("Mujhe saans lene mein mushkil ho rahi hai")
    print(json.dumps(result2, indent=2))

    print("\n=== Test 3: get_first_aid_question (injury flow, first question) ===")
    q1 = get_first_aid_question("injury", [])
    print(json.dumps(q1, indent=2))

    print("\n=== Test 4: get_first_aid_question (with previous answer) ===")
    q2 = get_first_aid_question(
        "injury",
        [{"question": q1["question"], "answer": "No"}],
    )
    print(json.dumps(q2, indent=2))