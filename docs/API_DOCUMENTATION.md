# DigitalVault Backend API Documentation

**Base URL:** `http://localhost:3000` (local development)

**Last Updated:** January 12, 2026

---

## Available Endpoints

### 1. IPFS Content Upload

**Endpoint:** `POST /api/ipfs/upload`

**Description:** Upload encrypted content (images, videos, documents) to IPFS via Pinata

**Request:**
- Method: POST
- Content-Type: multipart/form-data
- Body:
  - `file` (required): Binary file data
  - `metadata` (optional): JSON metadata object

**Response:**
```json
{
  "success": true,
  "ipfsHash": "QmXyZ...",
  "size": 1234567,
  "timestamp": "2026-01-12T20:30:00.000Z"
}
```

**Example (cURL):**
```bash
curl -X POST http://localhost:3000/api/ipfs/upload \
  -F "file=@photo.jpg" \
  -F 'metadata={"title":"My Photo","contentType":"PHOTO"}'
```

---

### 2. Get IPFS Content

**Endpoint:** `GET /api/ipfs/content/:cid`

**Description:** Retrieve content from IPFS by CID (Content Identifier)

**Parameters:**
- `cid` (path): IPFS Content ID (e.g., QmXyZ...)

**Response:** Binary content with appropriate Content-Type header

**Example (cURL):**
```bash
curl http://localhost:3000/api/ipfs/content/QmXyZ... --output downloaded.jpg
```

---

### 3. Upload Metadata JSON

**Endpoint:** `POST /api/ipfs/metadata`

**Description:** Upload JSON metadata to IPFS

**Request:**
```json
{
  "metadata": {
    "title": "My Content",
    "description": "Content description",
    "contentType": "POETRY",
    "creator": "0xAddress...",
    "timestamp": 1705090200
  }
}
```

**Response:**
```json
{
  "success": true,
  "ipfsHash": "QmMetadata...",
  "size": 256
}
```

---

### 4. Check Pin Status

**Endpoint:** `GET /api/ipfs/pin-status/:cid`

**Description:** Check if content is pinned on IPFS

**Response:**
```json
{
  "success": true,
  "isPinned": true,
  "pinCount": 1
}
```

---

### 5. Unpin Content

**Endpoint:** `DELETE /api/ipfs/unpin/:cid`

**Description:** Remove content from IPFS (owner only)

**Response:**
```json
{
  "success": true,
  "message": "Content unpinned successfully"
}
```

---

### 6. Health Check

**Endpoint:** `GET /health`

**Description:** Check if the service is running

**Response:**
```json
{
  "status": "healthy",
  "service": "ipfs-gateway"
}
```

---

## Error Responses

All endpoints return standard error format:

```json
{
  "success": false,
  "error": "Error message",
  "details": "Detailed error information"
}
```

**Common HTTP Status Codes:**
- 200: Success
- 400: Bad Request (missing parameters)
- 500: Internal Server Error

---

## Rate Limiting

- **Limit:** 100 requests per 15 minutes per IP address
- Headers returned:
  - `X-RateLimit-Limit`: Maximum requests allowed
  - `X-RateLimit-Remaining`: Requests remaining
  - `X-RateLimit-Reset`: Time when limit resets

---

## Security Notes

1. **File Size Limit:** 100MB per upload
2. **CORS:** Enabled for all origins (development only)
3. **Content Encryption:** Files should be encrypted client-side before upload
4. **Access Control:** Currently public (needs authentication in production)

---

## Integration Flow

### Uploading Content (Complete Flow)

1. **Client-Side Encryption:**
   ```dart
   // Encrypt content with AES-256-GCM
   final encrypted = EncryptionService.encrypt(fileBytes, encryptionKey);
   ```

2. **Upload to IPFS:**
   ```dart
   final formData = FormData.fromMap({
     'file': MultipartFile.fromBytes(encrypted.ciphertext, filename: 'content.enc'),
     'metadata': jsonEncode({'contentType': 'PHOTO'}),
   });
   final response = await dio.post('http://localhost:3000/api/ipfs/upload', data: formData);
   final ipfsHash = response.data['ipfsHash'];
   ```

3. **Register on Blockchain:**
   ```dart
   // Register with ContentRegistry contract
   await contentRegistry.registerContent(
     ipfsHash,
     contentType,
     accessModel,
     fileSize,
     encryptedKey, // Encrypted with user's public key
     previewUri,
   );
   ```

4. **Store Encrypted Key:**
   - Encrypt the content key with user's public key
   - Store encrypted key on blockchain
   - Only owner can decrypt with their private key

---

## Testing

See `docs/API_TESTS.md` for test scripts and examples.

---

## Future Endpoints (Not Yet Implemented)

These will be added in future iterations:

### Metadata Indexer (Port 3001)
- `GET /api/content/:contentId` - Get content metadata
- `GET /api/content/creator/:address` - List creator's content
- `GET /api/content/search` - Search content

### Storage Coordinator (Port 3002)
- `POST /api/storage/assign` - Assign storage provider
- `GET /api/storage/providers` - List available providers
- `POST /api/storage/verify` - Verify storage proof

### Notification Service (Port 3003)
- `POST /api/notify/push` - Send push notification
- `POST /api/notify/email` - Send email notification
- `GET /api/notify/preferences` - Get notification settings

---

## Environment Variables

Required in `.env` file:

```env
# IPFS Gateway
PORT=3000
PINATA_API_KEY=your_api_key_here
PINATA_SECRET_KEY=your_secret_key_here

# Database (for future services)
DB_HOST=localhost
DB_PORT=5432
DB_NAME=digitalvault
DB_USER=postgres
DB_PASSWORD=password

# Blockchain
RPC_URL=http://127.0.0.1:8545
CONTENT_REGISTRY_ADDRESS=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
MARKETPLACE_ADDRESS=0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
# ... (other contract addresses)
```
