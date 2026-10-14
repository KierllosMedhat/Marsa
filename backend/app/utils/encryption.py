import base64
import os
from typing import Union
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization

from app.config import get_settings


def resolve_encryption_key(key: Union[bytes, str, None] = None) -> bytes:
    """Resolve and validate a 32-byte AES-256 key from bytes, base64 string, or app settings."""
    raw_key = key if key is not None else get_settings().encryption_key
    if not raw_key:
        raise ValueError("Encryption key is not configured.")

    if isinstance(raw_key, str):
        # Try decoding as base64 first
        try:
            decoded = base64.b64decode(raw_key)
            if len(decoded) == 32:
                return decoded
        except Exception:
            pass
        # If not 32-byte base64, check raw string bytes
        key_bytes = raw_key.encode("utf-8")
        if len(key_bytes) == 32:
            return key_bytes
        raise ValueError(f"AES-256 key must be exactly 32 bytes. Got {len(key_bytes)} bytes.")
    elif isinstance(raw_key, bytes):
        if len(raw_key) == 32:
            return raw_key
        raise ValueError(f"AES-256 key must be exactly 32 bytes. Got {len(raw_key)} bytes.")
    else:
        raise TypeError(f"Invalid key type: {type(raw_key)}")


def encrypt_field(value: str | None, key: Union[bytes, str, None] = None) -> str | None:
    """Encrypt a sensitive field using AES-256-GCM.

    Returns a base64-encoded string combining 12-byte nonce + ciphertext + auth tag.
    Returns None if value is None.
    """
    if value is None:
        return None
    key_bytes = resolve_encryption_key(key)
    aesgcm = AESGCM(key_bytes)
    nonce = os.urandom(12)  # Standard 96-bit nonce for AES-GCM
    ciphertext = aesgcm.encrypt(nonce, value.encode("utf-8"), None)
    return base64.b64encode(nonce + ciphertext).decode("utf-8")


def decrypt_field(value: str | None, key: Union[bytes, str, None] = None) -> str | None:
    """Decrypt a sensitive field previously encrypted with AES-256-GCM.

    Returns the decrypted plaintext string.
    Returns None if value is None.
    """
    if value is None:
        return None
    key_bytes = resolve_encryption_key(key)
    aesgcm = AESGCM(key_bytes)
    try:
        raw_data = base64.b64decode(value)
        if len(raw_data) < 28:  # 12-byte nonce + 16-byte minimum tag
            raise ValueError("Encrypted data is too short to be valid AES-GCM ciphertext.")
        nonce = raw_data[:12]
        ciphertext = raw_data[12:]
        decrypted = aesgcm.decrypt(nonce, ciphertext, None)
        return decrypted.decode("utf-8")
    except Exception as e:
        raise ValueError(f"Failed to decrypt field: {e}") from e


def generate_rsa_key_pair() -> tuple[str, str]:
    """Generate a 2048-bit RSA key pair (private_pem, public_pem)."""
    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
    )
    private_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    ).decode("utf-8")
    public_pem = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    ).decode("utf-8")
    return private_pem, public_pem
