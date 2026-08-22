Jo mocked hissay hain aur baad mein replace honge:

classify_emergency() — Member 3 real Qwen call se replace karega
severity bump logic in record_event() — Step 2.3 mein real rule engine se wire hoga
contacts_notified list in escalate — Member 4 ka real FCM call
Step 2.3 — event endpoint ko real AI classification aur rule engine se wire karte hain.

Pehle ai_service.py ka stub banate hain (Member 3 baad mein isko real Qwen call se replace karega):


Note: summary_test case mein type "injury" se "unspecified" ho gaya kyunke jab answer event (empty description ke sath) aaya, classify_emergency("") ne "unknown" return kiya jisne pehle wala "injury" type overwrite kar diya. Ye Step 2.3 ka pehle se maujood behavior hai — abhi ke liye theek hai kyunke AI stub hai, lekin jab Member 3 real Qwen wire karega to ye edge case dobara dekhna hoga (shayad empty/non-descriptive answer events ko type overwrite nahi karna chahiye). Abhi isko chhorti hoon jab tak tum kaho fix karoon.

------------------------------------------------------------------------------------------------------------------------------------------------------
Member 2 (backend-core) ka kaam: haan, jo plan mein assign tha (Steps 2.1–2.4) woh complete ho gaya hai:

✅ Step 2.1 — 4 endpoints scaffold + mock responses + in-memory store
✅ Step 2.2 — deterministic safety rule engine + unit tests
✅ Step 2.3 — rule engine ko event endpoint mein wire karna
✅ Step 2.4 — status endpoint mein summary + timeline

Ye list hai jo Integration Day (Day 3) pe replace/update hoga:

Kya	Abhi kya hai	Kaun replace karega	Kis file mein
AI classification	Stub — hamesha "injury", severity 3 ya default severity 1 return karta hai	Member 3	app/services/ai_service.py
In-memory session store	Python dict, restart pe data gayab ho jata hai	Kisi ko real DB (RDS/Redis) se replace karna hoga (shayad Member 2 khud, baad mein)	app/repository/session_store.py
Trusted contacts (escalate response mein)	Hardcoded ["contact_001", "contact_002"]	Member 4	app/services/emergency_service.py (escalate function)
Push notifications (FCM)	Abhi call hi nahi ho rahi	Member 4	Naya integration point escalate mein
Location (mock lat/lng)	Hardcoded Lahore coordinates	Member 4 (WebSocket location service se real data aayegi)	app/services/emergency_service.py (status function)
Nearby hospitals/police	Abhi field hi nahi hai response mein	Member 4	get_status() mein add hoga

Isi tarah ye edge case bhi dekh lena baad mein: jab answer event empty description ke sath aata hai to type "injury" se "unknown" ho jata hai — jab real AI aayegi to ye recheck karna hoga.

PS D:\Rabia_Uni\Hackathon\emergency-assistant> curl -X POST http://127.0.0.1:8000/emergency/event -H "Content-Type: application/json" -d '{\"user_id\":\"rabia_1\",\"type\":\"trigger\",\"payload\":{\"description\":\"leg hurt after fall\"}}'
Invoke-WebRequest : Cannot bind parameter 
'Headers'. Cannot convert the "Content-Type: 
application/json" value of type "System.String" to 
type "System.Collections.IDictionary".
At line:1 char:55
+ ... .0.1:8000/emergency/event -H "Content-Type: 
application/json" -d '{\" ...
+                                  
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidArgument: (:)  
   [Invoke-WebRequest], ParameterBindingException
    + FullyQualifiedErrorId : CannotConvertArgument 
   NoMessage,Microsoft.PowerShell.Commands.InvokeW  
  ebRequestCommand

PS D:\Rabia_Uni\Hackathon\emergency-assistant>