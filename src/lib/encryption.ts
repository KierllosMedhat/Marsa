import crypto from 'crypto';

// 32-byte key for AES-256-GCM. Reads from ENCRYPTION_KEY env var or uses deterministic clinic key fallback.
function getEncryptionKey(): Buffer {
  const envKey = process.env.ENCRYPTION_KEY;
  if (envKey) {
    try {
      const buf = Buffer.from(envKey, 'base64');
      if (buf.length === 32) return buf;
    } catch {
      // fallback to hash
    }
    return crypto.createHash('sha256').update(envKey).digest();
  }
  return crypto
    .createHash('sha256')
    .update('marsa-psychiatric-clinic-aes-256-gcm-master-key-2026')
    .digest();
}

export function encryptField(plainText: string | null | undefined): string | null {
  if (!plainText) return null;
  const key = getEncryptionKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(plainText, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();
  // Format: iv(12 bytes) + authTag(16 bytes) + ciphertext -> hex
  return Buffer.concat([iv, authTag, encrypted]).toString('hex');
}

export function decryptField(cipherHex: string | null | undefined): string | null {
  if (!cipherHex) return null;
  try {
    const raw = Buffer.from(cipherHex, 'hex');
    if (raw.length < 28) return cipherHex; // Plaintext fallback if not encrypted hex
    const iv = raw.subarray(0, 12);
    const authTag = raw.subarray(12, 28);
    const encrypted = raw.subarray(28);
    const key = getEncryptionKey();
    const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(authTag);
    const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]);
    return decrypted.toString('utf8');
  } catch {
    // If already plaintext or legacy format, return as-is
    return cipherHex;
  }
}
