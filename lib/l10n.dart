/// Minimal two-language support. English text is the key; [tr] returns the
/// Urdu translation when Urdu is chosen, or the English text otherwise, so
/// an untranslated string simply stays in English.
library;

String appLanguage = 'en';

String tr(String en) => appLanguage == 'ur' ? (_ur[en] ?? en) : en;

const languages = {'en': 'English', 'ur': 'اردو'};

const _ur = <String, String>{
  // Home
  'Walk tall. Your circle is awake.': 'بے خوف چلیں۔ آپ کے اپنے جاگ رہے ہیں۔',
  'One slide tells your trusted buddies where you are.':
      'ایک سلائیڈ سے آپ کے بھروسے کے ساتھیوں کو آپ کی جگہ پتا چل جاتی ہے۔',
  'Your SOS buddies': 'آپ کے SOS ساتھی',
  'Manage': 'ترتیب دیں',
  // Helplines
  'Emergency helplines': 'ایمرجنسی ہیلپ لائنز',
  'Police': 'پولیس',
  'Rescue / Ambulance': 'ریسکیو / ایمبولینس',
  'Madadgar (women & children)': 'مددگار (خواتین اور بچے)',
  'Edhi Ambulance': 'ایدھی ایمبولینس',
  'Call': 'کال کریں',
  'Nearest police station': 'قریبی تھانہ',
  'Nearest hospital': 'قریبی ہسپتال',
  'Open the map around you': 'اپنے آس پاس کا نقشہ کھولیں',
  'Could not open the map.': 'نقشہ نہیں کھل سکا۔',
  'Could not open the phone dialer.': 'فون ڈائلر نہیں کھل سکا۔',
  // Check-in
  'Safe-walk check-in': 'محفوظ واپسی چیک اِن',
  'SOS starts if you do not check in on time.':
      'وقت پر چیک اِن نہ کیا تو SOS شروع ہو جائے گا۔',
  'Check in by': 'چیک اِن کا وقت',
  "I'm safe": 'میں محفوظ ہوں',
  '15 min': '15 منٹ',
  '30 min': '30 منٹ',
  '1 hour': '1 گھنٹہ',
  '2 hours': '2 گھنٹے',
  '+15 min': '+15 منٹ',
  // Trip
  'Share my trip': 'میرا سفر شیئر کریں',
  'Buddies see you live until you arrive.':
      'پہنچنے تک ساتھی آپ کی لائیو جگہ دیکھیں گے۔',
  'Sharing live until': 'لائیو شیئرنگ جاری، وقت',
  "I've arrived": 'میں پہنچ گئی',
  'is on the way': 'راستے میں ہے',
  'Waiting for their location': 'جگہ کا انتظار ہے',
  'Add an SOS buddy who has approved you first.':
      'پہلے ایسا SOS ساتھی شامل کریں جس نے منظوری دی ہو۔',
  // Medical
  'Medical info': 'طبی معلومات',
  'Shared with your buddies only during an SOS.':
      'صرف SOS کے دوران آپ کے ساتھیوں کو دکھائی جاتی ہے۔',
  'Blood group': 'بلڈ گروپ',
  'Allergies, medicines, conditions': 'الرجی، دوائیں، بیماریاں',
  'Leave empty to share nothing.': 'کچھ شیئر نہ کرنا ہو تو خالی چھوڑ دیں۔',
  'Save': 'محفوظ کریں',
  // Incoming SOS
  'needs help': 'کو مدد چاہیے',
  'ended the SOS': 'نے SOS ختم کر دیا',
  'This alert is no longer available.': 'یہ الرٹ اب دستیاب نہیں۔',
  'Last known location': 'آخری معلوم جگہ',
  'Ended here': 'یہاں ختم ہوا',
  'Location unavailable. Waiting for a connection.':
      'جگہ دستیاب نہیں۔ کنکشن کا انتظار ہے۔',
  'Map': 'نقشہ',
  'Watch live camera': 'لائیو کیمرہ دیکھیں',
  'Call 15': '15 پر کال کریں',
  'SafeHer only opens your phone dialer. You choose whether to call.':
      'SafeHer صرف ڈائلر کھولتا ہے، کال کرنا آپ کی مرضی ہے۔',
  "I'm on my way": 'میں آ رہی ہوں',
  'I have seen this': 'میں نے دیکھ لیا',
  'LIVE': 'لائیو',
  'ENDED': 'ختم',
  // SOS sheet
  'Slide to send SOS': 'SOS بھیجنے کے لیے سلائیڈ کریں',
  'Add an SOS buddy first': 'پہلے SOS ساتھی شامل کریں',
  'SOS STARTING': 'SOS شروع ہو رہا ہے',
  'Sending your alert': 'آپ کا الرٹ بھیجا جا رہا ہے',
  'Cancel': 'منسوخ کریں',
  'SOS is active': 'SOS فعال ہے',
  'Your live location is being tracked on this phone.':
      'آپ کی لائیو جگہ اس فون پر ریکارڈ ہو رہی ہے۔',
  'Your live location, camera and microphone are going to your SOS buddies right now.':
      'آپ کی لائیو جگہ، کیمرہ اور مائیک ابھی آپ کے SOS ساتھیوں کو جا رہے ہیں۔',
  'On the way': 'راستے میں',
  'Seen': 'دیکھ لیا',
  'No buddy has opened it yet. SafeHer will remind them every 2 minutes.':
      'ابھی کسی ساتھی نے نہیں کھولا۔ SafeHer ہر 2 منٹ بعد یاد دلائے گا۔',
  'No internet? Text my location': 'انٹرنیٹ نہیں؟ SMS سے جگہ بھیجیں',
  'I am safe · End SOS': 'میں محفوظ ہوں · SOS ختم کریں',
  'Use the app · SOS keeps running': 'ایپ استعمال کریں · SOS جاری رہے گا',
  // Settings
  'Language': 'زبان',
  'Silent SOS': 'خاموش SOS',
  'Shake to SOS': 'ہلا کر SOS',
  'Block screenshots': 'اسکرین شاٹ بند کریں',
  'Emergency PIN': 'ایمرجنسی PIN',
};
