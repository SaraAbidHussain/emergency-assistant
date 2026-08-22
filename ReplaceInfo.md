Jo mocked hissay hain aur baad mein replace honge:

classify_emergency() — Member 3 real Qwen call se replace karega
severity bump logic in record_event() — Step 2.3 mein real rule engine se wire hoga
contacts_notified list in escalate — Member 4 ka real FCM call
Step 2.3 — event endpoint ko real AI classification aur rule engine se wire karte hain.

Pehle ai_service.py ka stub banate hain (Member 3 baad mein isko real Qwen call se replace karega):


Note: summary_test case mein type "injury" se "unspecified" ho gaya kyunke jab answer event (empty description ke sath) aaya, classify_emergency("") ne "unknown" return kiya jisne pehle wala "injury" type overwrite kar diya. Ye Step 2.3 ka pehle se maujood behavior hai — abhi ke liye theek hai kyunke AI stub hai, lekin jab Member 3 real Qwen wire karega to ye edge case dobara dekhna hoga (shayad empty/non-descriptive answer events ko type overwrite nahi karna chahiye). Abhi isko chhorti hoon jab tak tum kaho fix karoon.
