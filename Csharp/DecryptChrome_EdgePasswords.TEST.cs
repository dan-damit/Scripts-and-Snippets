// Decrypt Chrome/Edge password using AES-GCM
private async Task<byte[]> GetDecryptedKeyAsync(string localStatePath)
{
    using var stream = File.OpenRead(localStatePath);
    var json = await JsonDocument.ParseAsync(stream);
    string encryptedKeyBase64 = json.RootElement
        .GetProperty("os_crypt")
        .GetProperty("encrypted_key")
        .GetString()!;

    byte[] encryptedKey = Convert.FromBase64String(encryptedKeyBase64);
    byte[] dpapiBlob = encryptedKey.Skip(5).ToArray(); // Strip "DPAPI" prefix
    return ProtectedData.Unprotect(dpapiBlob, null, DataProtectionScope.CurrentUser);
}

// Decrypt individual password entry
private string DecryptPassword(byte[] encryptedData, byte[] aesKey)
{
    const int PrefixLen = 3;    // "v10"
    const int IvLen = 12;       // 96-bit IV
    const int TagLen = 16;      // 128-bit tag

    if (encryptedData == null || encryptedData.Length < PrefixLen + IvLen + TagLen)
        return "[UNABLE TO DECRYPT: blob too small]";

    if (aesKey == null || (aesKey.Length != 16 && aesKey.Length != 24 && aesKey.Length != 32))
        return "[UNABLE TO DECRYPT: invalid aes key length]";

    try
    {
        var iv = new byte[IvLen];
        Buffer.BlockCopy(encryptedData, PrefixLen, iv, 0, IvLen);

        int cipherStart = PrefixLen + IvLen;
        int cipherLen = encryptedData.Length - cipherStart - TagLen;
        if (cipherLen <= 0)
            return "[UNABLE TO DECRYPT: no ciphertext]";

        var ciphertext = new byte[cipherLen];
        Buffer.BlockCopy(encryptedData, cipherStart, ciphertext, 0, cipherLen);

        var tag = new byte[TagLen];
        Buffer.BlockCopy(encryptedData, encryptedData.Length - TagLen, tag, 0, TagLen);

        var plaintext = new byte[ciphertext.Length];

        // Explicit tag size constructor to silence SYSLIB0053 warning
        using var aes = new AesGcm(aesKey, TagLen);
        aes.Decrypt(iv, ciphertext, tag, plaintext);

        return Encoding.UTF8.GetString(plaintext);
    }
    catch (CryptographicException cex)
    {
        return $"[UNABLE TO DECRYPT: authentication failed {cex.Message}]";
    }
    catch (Exception ex)
    {
        return $"[UNABLE TO DECRYPT: {ex.Message}]";
    }
}