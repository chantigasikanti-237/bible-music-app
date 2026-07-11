from pydub import AudioSegment
import os

# Create directories if they don't exist
os.makedirs(r'c:\Users\anilv\bible_app\assets\audio\en', exist_ok=True)
os.makedirs(r'c:\Users\anilv\bible_app\assets\audio\te', exist_ok=True)

# Create 5 second silent audio files
silent = AudioSegment.silent(duration=5000)

# English audio files
silent.export(r'c:\Users\anilv\bible_app\assets\audio\en\genesis_1.mp3', format='mp3')
silent.export(r'c:\Users\anilv\bible_app\assets\audio\en\genesis_2.mp3', format='mp3')

# Telugu audio files (already created, but ensure they exist)
silent.export(r'c:\Users\anilv\bible_app\assets\audio\te\genesis_1.mp3', format='mp3')
silent.export(r'c:\Users\anilv\bible_app\assets\audio\te\genesis_2.mp3', format='mp3')

print("Audio files created successfully!")
