namespace UniSpeech
{
    public interface ISpeechRecognizer
    {
        void OnRecognized(string transcription);
        void OnError(string description);
        void OnFinished();
        void OnAuthorized();
        void OnUnauthorized();
        void OnAvailable();
        void OnUnavailable();
    }
}

