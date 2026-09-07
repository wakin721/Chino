from dataclasses import dataclass
from typing import Any

from .errors import ProtocolError

PROTOCOL_VERSION = 1
VALID_ACTIONS = {'ping', 'load_model', 'predict', 'shutdown'}


@dataclass(frozen=True)
class Request:
    request_id: str
    action: str
    payload: dict[str, Any]


def parse_request(payload: dict[str, Any]) -> Request:
    if payload.get('protocol') != PROTOCOL_VERSION:
        raise ProtocolError('unsupported_protocol', 'Only protocol version 1 is supported.')
    request_id = payload.get('request_id')
    if not isinstance(request_id, str) or not request_id:
        raise ProtocolError('invalid_request', 'request_id is required.')
    action = payload.get('action')
    if action not in VALID_ACTIONS:
        raise ProtocolError('invalid_action', f'Unsupported action: {action}')
    return Request(request_id=request_id, action=action, payload=payload)


def success_response(request_id: str, action: str, **fields: Any) -> dict[str, Any]:
    return {'protocol': PROTOCOL_VERSION, 'request_id': request_id, 'ok': True, 'action': action, **fields}


def error_response(request_id: str | None, code: str, message: str) -> dict[str, Any]:
    return {
        'protocol': PROTOCOL_VERSION,
        'request_id': request_id or '',
        'ok': False,
        'error': {'code': code, 'message': message},
    }
