import os
from google import genai
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
client = genai.Client(api_key=GEMINI_API_KEY)

def simple_request():
    response = client.models.generate_content(
        model="gemini-2.5-flash", contents="Explain how AI works in a few words"
    )
    print(response.text)

def upload_file():
    myfile = client.files.upload(file="/Users/atacan/Developer/Repositories/GoogleGenerativeLanguage/assets/speech.mp3")

    response = client.models.generate_content(
        model="gemini-2.0-flash", contents=["Describe this audio clip", myfile]
    )

    print(response.text)

def main():
    # simple_request()
    upload_file()


if __name__ == "__main__":
    main()
