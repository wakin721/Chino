import pytest
from chino_inference.protocol import parse_request, error_response
from chino_inference.errors import ProtocolError


def test_parse_predict_request_requires_request_id():
    with pytest.raises(ProtocolError):
        parse_request({'protocol': 1, 'action': 'predict', 'image_path': 'a.jpg'})


def test_error_response_is_machine_readable():
    payload = error_response('abc', 'invalid_request', 'bad request')
    assert payload == {'protocol': 1, 'request_id': 'abc', 'ok': False, 'error': {'code': 'invalid_request', 'message': 'bad request'}}
