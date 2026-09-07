def resolve_device(device: str) -> str:
    if device == 'cpu':
        return 'cpu'
    if device == 'cuda':
        try:
            import torch
        except ImportError as exc:
            raise RuntimeError('PyTorch is not installed.') from exc
        if not torch.cuda.is_available():
            raise RuntimeError('CUDA is not available.')
        return 'cuda'
    if device != 'auto':
        raise ValueError(f'Unsupported device: {device}')
    try:
        import torch
        return 'cuda' if torch.cuda.is_available() else 'cpu'
    except ImportError:
        return 'cpu'
