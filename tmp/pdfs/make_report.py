from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor
from reportlab.lib.utils import simpleSplit
import fitz

root=Path(__file__).resolve().parents[2]
out=root/'output/pdf'
out.mkdir(parents=True,exist_ok=True)
pdf=out/'SafeHer_FYP_Nimra_Zainab.pdf'
doc=canvas.Canvas(str(pdf),pagesize=(595,842))
doc.setTitle('SafeHer | Nimra Zainab | Final Year Project')
doc.setAuthor('Nimra Zainab')
ink='#35162B'; pink='#C2255C'; muted='#6A3A52'
page_number=0
def text(value,x,y,size=11,color=ink,font='Helvetica'):
    doc.setFillColor(HexColor(color)); doc.setFont(font,size); doc.drawString(x,y,value)
def para(value,y,size=11,width=491):
    for line in simpleSplit(value,'Helvetica',size,width):
        text(line,52,y,size); y-=17
    return y-12
def start(kicker,title):
    global page_number
    page_number+=1
    doc.setFillColor(HexColor('#FFF7F3')); doc.rect(0,0,595,842,fill=1,stroke=0)
    doc.setFillColor(HexColor('#FADCE4')); doc.roundRect(28,694,539,120,24,fill=1,stroke=0)
    text('SAFEHER  /  FINAL YEAR PROJECT',52,784,10,pink,'Helvetica-Bold')
    text(kicker.upper(),52,758,9,muted)
    text(title,52,723,25,ink,'Helvetica-Bold')
    text('Nimra Zainab  |  BS, 8th Semester',40,30,9,muted)
    text(f'Punjab College, Muzaffargarh  /  {page_number:02}',338,30,9,muted)
def end(): doc.showPage()
def section(title,body,y):
    text(title,52,y,14,pink,'Helvetica-Bold')
    return para(body,y-24)
def screens(title,first,second,captions):
    start('Mobile interface / actual application preview',title)
    for x,name,caption in zip([61,322],[first,second],captions):
        doc.setFillColor(HexColor('#EBCFD6'))
        doc.roundRect(x-5,186,228,486,29,fill=1,stroke=0)
        doc.setFillColor(HexColor('#77727A'))
        doc.roundRect(x-9,193,230,486,29,fill=1,stroke=0)
        doc.setFillColor(HexColor('#17151B'))
        doc.roundRect(x-7,195,226,482,27,fill=1,stroke=0)
        doc.setFillColor(HexColor('#4A454F'))
        doc.roundRect(x-11,558,3,42,1.5,fill=1,stroke=0)
        doc.roundRect(x+220,542,3,57,1.5,fill=1,stroke=0)
        doc.setFillColor(HexColor('#FFF7F3'))
        doc.roundRect(x,203,212,466,21,fill=1,stroke=0)
        doc.saveState()
        screen_clip=doc.beginPath()
        screen_clip.roundRect(x,211,212,439,15)
        doc.clipPath(screen_clip,stroke=0,fill=0)
        doc.drawImage(str(root/'tmp/pdfs/screens'/f'{name}.png'),x+4.5,211,width=203,height=439,mask='auto')
        doc.restoreState()
        doc.setFillColor(HexColor('#17151B'))
        doc.roundRect(x+83,657,38,4,2,fill=1,stroke=0)
        doc.circle(x+132,659,3,fill=1,stroke=0)
        doc.setFillColor(HexColor('#424253'))
        doc.circle(x+132,659,1.3,fill=1,stroke=0)
        doc.setFillColor(HexColor('#35162B'))
        doc.roundRect(x+78,206,56,2.5,1.2,fill=1,stroke=0)
        text(caption,x,169,12,pink,'Helvetica-Bold')
    para('Captured from the Flutter app at a 390 x 844 mobile viewport. Local design-preview mode uses sample data; these images do not demonstrate live delivery or physical Android-device testing.',123,10)
    end()

start('BS / 8th semester / project presentation','Safety, within reach.')
text('SafeHer',52,623,48,pink,'Helvetica-Bold')
para('Women Safety & Emergency Coordination Application',584,17)
y=section('Designed & developed by','Nimra Zainab',515)
y=section('Academic programme','BS, 8th Semester | Punjab College, Muzaffargarh',y-14)
y=section('Current milestone','70% ready - design and development presentation stage.',y-14)
para('The 70% figure is the developer-provided project progress estimate, not a measured production-readiness or security certification. Remaining work includes reliable real-time messaging, an AI-assisted emergency calling workflow for 15, and completion and validation of end-to-end encryption.',y-6)
text('PROJECT REPORT  /  NOVEMBER 2026',52,114,11,pink,'Helvetica-Bold')
end()
start('01 / project overview','Purpose & ownership')
y=section('What is SafeHer?','SafeHer is a mobile-first women safety application designed to connect a user with trusted buddies during an emergency. It brings SOS initiation, contact management, chat, location-related coordination and safety preferences into one interface.',650)
y=section('Problem addressed','During a stressful situation, searching for contacts and explaining where help is needed can take time. SafeHer aims to make the emergency journey clear: select trusted people, request approval, initiate SOS and manage the event from a central screen.',y)
y=section('Design-to-development credit','Project concept, user-interface design, screen flows, frontend development and backend integration work are credited to Nimra Zainab for this BS 8th-semester Final Year Project, as supplied for this presentation.',y)
y=section('Presentation boundary','This submission presents the current design and implementation foundation. Features visible in the interface or present in source code are distinguished from live services that still need integration, hardening and multi-device validation.',y)
section('Primary user journey','Create an account > configure a profile > add buddies > obtain SOS approval > start an emergency alert > communicate and share location > cancel or resolve the incident.',y)
end()
start('02 / functionality inventory','Accounts & communication')
y=650
for title,body in [
('Account access','Login, registration, password recovery and username setup screens establish the account journey. Firebase Authentication integration is present in the source; successful production authentication is not verified by this presentation.'),
('Profile & personalisation','Edit profile information, choose a profile photo and use the photo crop workflow. Appearance preferences support light, dark and system themes.'),
('Trusted buddies','Search for users, send and respond to friend requests, manage buddy relationships and select SOS recipients with a separate approval/consent flow.'),
('Chat & media','Conversation and chat-settings screens provide the communication interface. Source modules include text messaging, photos, voice recording, delivery/read handling and presence. Reliable real-time delivery remains a completion milestone.'),
('Audio & video calling','Call screens, signaling and WebRTC modules form the call foundation. Connectivity, permissions, relay configuration and real-device behavior still require verification; the AI-assisted 15 calling workflow is planned work.')]: y=section(title,body,y)
end()
start('03 / functionality inventory','Emergency & privacy')
y=650
for title,body in [
('SOS activation & lifecycle','The home screen focuses on SOS activation. Countdown and event controls support starting, cancelling and resolving an emergency, with routing intended for approved SOS buddies.'),
('Location & incident activity','Location-service and SOS map components support emergency coordination. Activity screens present incident history/status. Location freshness and continuous delivery need device-level validation.'),
('Alerts & permissions','Notification, alert sound, microphone, camera and location-related components are included. Permission screens explain required access. Platform and background behavior must be tested on Android.'),
('Shortcut & safety preferences','Settings provide SOS preferences and an Android volume-key shortcut flow. Browser preview is not evidence that hardware or background shortcuts work.'),
('Privacy, PIN & backup','Privacy guidance, PIN/app-lock screens and backup/restore modules are part of the project. Encryption code exists, but complete key lifecycle, recovery behavior and end-to-end security validation remain pending.')]: y=section(title,body,y)
end()
screens('Access & onboarding','login','register',['01  Login','02  Create account'])
screens('Emergency & trusted people','home','buddies',['03  Safety dashboard','04  Buddies'])
screens('Conversations & activity','chat','activity',['05  Conversation','06  Activity'])
screens('Controls & consent','settings','sosbuddies',['07  Settings','08  SOS buddies'])
screens('Profile & permissions','editprofile','permissions',['09  Edit profile','10  Permissions'])
start('04 / engineering','Frontend & Firebase backend')
y=section('Frontend: Flutter + Dart','The app is built with Flutter and Dart, using Material components and a shared design-token system. The mobile layout uses rounded cards, clear navigation and a prominent emergency action. Local state and preferences are supported by Hive.',650)
y=section('Visual system','This report follows the app light palette: warm ivory #FFF7F3, baby pink #FADCE4, primary rose #C2255C and deep plum #35162B. The app also includes a dark theme.',y)
y=section('Firebase real-time architecture','Firebase is the backend platform. Cloud Firestore source integration handles profiles, relationships, chats and SOS records through live listeners. Firebase Realtime Database is used by the presence channel. These are distinct services within the same Firebase ecosystem.',y)
y=section('Supporting backend services','Firebase Authentication supports identity; Cloud Functions provide server-side operations; Cloud Messaging supports push delivery; Storage and backup modules support media/data workflows. Firestore, Realtime Database and Storage rule files are included in the repository.',y)
section('Data flow & trust boundary','Flutter interface > controllers/services > authenticated Firebase services > authorized recipient clients. Security rules and server validation must enforce ownership and consent. Code presence does not prove that deployment, permissions or live delivery are complete.',y)
end()
start('05 / progress and future work','70% ready. Next: integration.')
y=section('Current presentation milestone','The developer reports approximately 70% completion. The interface, major user journeys and backend integration foundation are ready to be presented as an FYP design/development milestone. No feature-by-feature percentage audit has been performed.',650)
y=section('Remaining: real-time messaging','Complete and validate separate-device message synchronization, online/offline presence, delivery/read receipts, media transfer, reconnection behavior and notification handling.',y)
y=section('Remaining: AI-assisted calling for 15','Develop the proposed AI-assisted emergency calling workflow for 15, with explicit user control, accurate information handling and a clearly defined integration mechanism. It is a planned capability, not an operational service shown by this report.',y)
y=section('Remaining: end-to-end encryption','Finish and verify encryption across supported message/media flows, key storage and exchange, recipient identity checks, device changes and recovery. The repository contains X25519-based encryption work; this is not a completed security assurance.',y)
section('Completion criteria','Validate sender and recipient Android devices; test consent revocation and denied access; confirm SOS delivery and location freshness; verify calls and notification states; review encryption and backup behavior; document results before a final release.',y)
end()
start('06 / demonstration & evidence','FYP presentation checklist')
y=section('Suggested demonstration','Introduce the problem and developer. Show registration/login, the SOS dashboard, buddies and consent, chat and activity. Finish with settings and permissions, the Flutter/Firebase architecture, the 70% milestone and the remaining roadmap.',650)
y=section('Evidence used in this report','Screenshots were captured from the actual Flutter web build in local design-preview mode at mobile dimensions. The frontend and backend descriptions were reviewed against the project source, dependency manifest and service modules.',y)
y=section('Source baseline','Repository: github.com/hammadansar49-prog/women-safety-and-emergency-app\nReviewed baseline: fdf6dce (main). The repository README contains historical status notes; current source modules informed this report where implementation had progressed.',y)
y=section('Limitations of this demonstration','Screenshots are mobile browser previews of the shared Flutter interface, not photographs of an installed APK. Live Firebase deployment, emergency call handling, end-to-end security and physical-device reliability are not certified by this report.',y)
section('Academic attribution','Nimra Zainab | BS, 8th Semester\nPunjab College, Muzaffargarh\nFinal Year Project: SafeHer - Women Safety & Emergency Coordination',y)
end()
doc.save()
render=fitz.open(pdf)
for index,page in enumerate(render):
    page.get_pixmap(matrix=fitz.Matrix(0.85,0.85)).save(str(root/'tmp/pdfs'/f'page-{index+1:02}.png'))
print(f'{pdf} | {len(render)} pages')
