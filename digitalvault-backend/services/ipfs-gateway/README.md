# IPFS Gateway Service v2.0

Production-ready IPFS gateway with Pinata integration, encrypted content support, and PRE-awareness for DigitalVault platform.

## Features

- **File Upload**: Upload encrypted content to IPFS via Pinata
- **Metadata Management**: JSON metadata storage and retrieval
- **Pin Tracking**: PostgreSQL database for upload/pin tracking
- **PRE Support**: Special handling for proxy re-encryption content
- **Access Logging**: Track content access patterns
- **Rate Limiting**: Prevent abuse with configurable limits
- **Health Monitoring**: Comprehensive health checks
- **Docker Ready**: Full Docker and docker-compose support

## Quick Start

### Docker (Recommended)
```bash
cd services/ipfs-gateway
cp .env.example .env
# Edit .env with Pinata credentials
docker-compose up -d
```

### Local
```bash
npm install
cp .env.example .env
# Edit .env and set up PostgreSQL
npm start
```

## API Endpoints

**Base URL:** `http://localhost:3000`

### Upload
- `POST /api/ipfs/upload/file` - Upload file (multipart/form-data)
- `POST /api/ipfs/upload/metadata` - Upload metadata JSON
- `POST /api/ipfs/upload/json` - Upload arbitrary JSON

### Content
- `GET /api/ipfs/content/:cid` - Retrieve content
- `GET /api/ipfs/content/:cid/info` - Get content info
- `GET /api/ipfs/content/by-content-id/:contentId` - Get uploads by content ID

### Pin Management
- `GET /api/ipfs/pin/status/:cid` - Check pin status
- `GET /api/ipfs/pin/list` - List all pins
- `DELETE /api/ipfs/pin/:cid` - Unpin content
- `GET /api/ipfs/pin/stats` - Get statistics

### Health
- `GET /api/ipfs/health` - Basic health check
- `GET /api/ipfs/health/detailed` - Detailed health check

## Database Schema

### uploads
Tracks all uploaded content.

**Fields:** cid, content_id, uploader_address, file_name, file_size, mime_type, is_encrypted, is_pre_content, metadata_cid, pin_status, created_at, accessed_at, access_count

### pins
Tracks pin status.

**Fields:** cid, pin_type, status, size, pinned_at, unpinned_at, metadata

### access_logs
Logs content access.

**Fields:** cid, accessor_address, access_type, ip_address, accessed_at

## Configuration

See `.env.example` for all configuration options.

**Required:**
- `PINATA_API_KEY` or `PINATA_JWT`
- `DB_PASSWORD`

## Testing

```bash
npm test
```

## License

MIT

---

**IPFS Gateway v2.0** - Built for DigitalVault Week 10 🚀
