class ChinoInferenceError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class ProtocolError(ChinoInferenceError):
    pass


class ModelError(ChinoInferenceError):
    pass
