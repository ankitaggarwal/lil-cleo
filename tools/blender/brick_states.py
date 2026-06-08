"""Per-state presentation: which swappable face + which props/effects are shown
for each rendered state. Imported by render_states.py. Pure data.

Face objects:  Face_neutral, Face_happy, Face_sad, Face_angry, Face_surprised,
               Face_sleepy, Face_love, Face_thinking, Face_curious, Face_worried,
               Face_dead, Face_wink, Face_laughing
Prop objects:  Mug, MugSteam, Bulb, MagRing, WrenchBar, TrophyCup, PartyHat,
               Confetti, Raincloud, Headphones, Book, Laptop, Clip, Hourglass,
               Hairfire, Sweat, Zzz, Sparkles, Tears, Exclaim, Question, Bolt
"""

ALL_FACES = ["Face_neutral", "Face_happy", "Face_sad", "Face_angry",
             "Face_surprised", "Face_sleepy", "Face_love", "Face_thinking",
             "Face_curious", "Face_worried", "Face_dead", "Face_wink",
             "Face_laughing"]

ALL_PROPS = ["Mug", "MugSteam", "Bulb", "MagRing", "WrenchBar", "TrophyCup",
             "PartyHat", "Confetti", "Raincloud", "Headphones", "Book",
             "Laptop", "Clip", "Hourglass", "Hairfire", "Sweat", "Zzz",
             "Sparkles", "Tears", "Exclaim", "Question", "Bolt", "BigHeart"]

# state -> face name (default Face_neutral when unlisted)
FACE_FOR = {
    # happy family
    "happy": "happy", "smiling": "happy", "excited": "happy",
    "celebrate": "happy", "proud": "happy", "relieved": "happy",
    "peace": "happy", "fistpump": "happy", "thumbsup": "happy",
    "party": "happy", "trophy": "happy", "dance": "happy",
    "salute": "happy", "idea": "happy", "clap": "happy",
    "laughing": "laughing",
    "love": "love",
    # sad family
    "sad": "sad", "crying": "sad", "facepalm": "sad",
    "raincloud": "sad",
    # bored / droopy
    "bored": "sleepy",
    # angry / focused
    "angry": "angry", "determined": "angry",
    "smug": "wink",
    # surprised / scared
    "surprised": "surprised", "panic": "surprised", "scared": "surprised",
    "hairfire": "surprised", "sweating": "worried",
    # thinking / curious / confused
    "thinking": "thinking", "debug": "thinking", "reading": "thinking",
    "coding": "thinking", "clipboard": "thinking",
    "curious": "curious",
    "confused": "worried", "nervous": "worried", "embarrassed": "wink",
    # sleepy
    "sleeping": "sleepy", "yawn": "sleepy", "meditate": "sleepy",
    # error / glitch
    "glitch": "dead", "loading": "neutral",
}

# state -> list of prop/effect objects to reveal
SHOW_FOR = {
    "excited": ["Sparkles"],
    "proud": ["Sparkles"],
    "sleeping": ["Zzz"],
    "coffee": ["Mug", "MugSteam"],
    "idea": ["Bulb"],
    "debug": ["MagRing"],
    "fixing": ["WrenchBar"],
    "trophy": ["TrophyCup"],
    "party": ["PartyHat", "Confetti"],
    "raincloud": ["Raincloud"],
    "headphones": ["Headphones"],
    "reading": ["Book"],
    "coding": ["Laptop"],
    "clipboard": ["Clip"],
    "loading": ["Hourglass"],
    "hairfire": ["Hairfire"],
    "sweating": ["Sweat"],
    "celebrate": ["Sparkles"],
    "crying": ["Tears"],
    "confused": ["Question"],
    "curious": ["Question"],
    "surprised": ["Exclaim"],
    "glitch": ["Bolt"],
    "love": ["BigHeart"],
}


def face_for(state):
    return "Face_" + FACE_FOR.get(state, "neutral")


def props_for(state):
    return SHOW_FOR.get(state, [])
