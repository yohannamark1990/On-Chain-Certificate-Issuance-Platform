# 🎓 On-Chain Certificate Issuance Platform

A decentralized platform for issuing and verifying academic and professional certificates using NFTs on the Stacks blockchain. Built with Clarity smart contracts for transparent, tamper-proof credential management.

## 🌟 Features

- 🏛️ **Institution Registration**: Educational institutions can register and get verified
- 📜 **Certificate Issuance**: Issue certificates as NFTs with metadata and verification codes  
- ✅ **Instant Verification**: Employers can verify certificate authenticity in real-time
- 🔄 **Certificate Transfer**: Recipients can transfer certificates to new owners
- ❌ **Revocation System**: Institutions can revoke certificates if needed
- 🔍 **Expiry Tracking**: Support for certificates with expiration dates

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
clarinet new certificate-platform
cd certificate-platform
```

Copy the contract code to `contracts/certificate-platform.clar`

### Testing

```bash
clarinet console
```

## 📖 Usage

### For Institutions

#### 1. Register Institution
```clarity
(contract-call? .certificate-platform register-institution "Harvard University")
```

#### 2. Issue Certificate
```clarity
(contract-call? .certificate-platform issue-certificate 
  'ST1RECIPIENT123 
  "Bachelor's Degree" 
  "Computer Science - Bachelor of Science"
  (some u1000000)
  "https://metadata.example.com/cert1"
  "ABC123XYZ789")
```

#### 3. Revoke Certificate
```clarity
(contract-call? .certificate-platform revoke-certificate u1)
```

### For Recipients

#### Transfer Certificate
```clarity
(contract-call? .certificate-platform transfer-certificate u1 'ST1NEWOWNER456)
```

### For Verifiers

#### Verify Certificate
```clarity
(contract-call? .certificate-platform verify-certificate u1 "ABC123XYZ789")
```

#### Check Certificate Details
```clarity
(contract-call? .certificate-platform get-certificate u1)
```

#### Validate Certificate Status
```clarity
(contract-call? .certificate-platform is-certificate-valid u1)
```

## 🔧 Contract Functions

### Public Functions

| Function | Description |
|----------|-------------|
| `register-institution` | Register a new educational institution |
| `verify-institution` | Verify an institution (admin only) |
| `issue-certificate` | Issue a new certificate NFT |
| `revoke-certificate` | Revoke an existing certificate |
| `transfer-certificate` | Transfer certificate ownership |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-certificate` | Get certificate details |
| `get-institution` | Get institution information |
| `verify-certificate` | Verify certificate with code |
| `is-certificate-valid` | Check if certificate is valid |
| `get-certificate-owner` | Get current certificate owner |

## 🏗️ Architecture

- **NFT-Based**: Each certificate is a unique NFT
- **Verification Codes**: Unique codes for quick verification
- **Institution Registry**: Verified institutions can issue certificates
- **Metadata Support**: Rich certificate information via URIs
- **Revocation System**: Institutions can invalidate certificates

## 🔐 Security Features

- ✅ Only verified institutions can issue certificates
- ✅ Certificate ownership tracked via NFTs
- ✅ Tamper-proof verification codes
- ✅ Revocation capabilities for institutions
- ✅ Transfer restrictions for revoked certificates

## 🎯 Use Cases

- 🎓 **Universities**: Issue diplomas and degrees
- 🏢 **Professional Bodies**: Certify professional qualifications  
- 📚 **Online Courses**: Verify completion certificates
- 🏆 **Training Programs**: Authenticate skill certifications
- 🔬 **Research Institutions**: Validate research credentials

## 📊 Error Codes

| Code | Description |
|------|-------------|
| u100 | Not authorized |
| u101 | Certificate not found |
| u102 | Already exists |
| u103 | Invalid recipient |
| u104 | Institution not registered |
| u105 | Certificate revoked |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

---

Built with ❤️ using Clarity and Stacks blockchain
```

**Git Commit Message:**
```
feat: implement on-chain certificate issuance platform with NFT-based credentials
```

**GitHub Pull Request Title:**
```
🎓 Add On-Chain Certificate Issuance Platform MVP
```

**GitHub Pull Request Description:**
```
## Summary
Implements a complete on-chain certificate issuance platform that allows educational institutions to issue verifiable academic and professional certificates as NFTs.

## What's Added
- ✅ Institution registration and verification system
- ✅ Certificate issuance as NFTs with metadata
- ✅ Real-time certificate verification with unique codes
- ✅ Certificate transfer and revocation capabilities
- ✅ Expiry date support and validation
- ✅ Comprehensive read-only functions for verification

## Key Features
- 🏛️ Verified institution registry
- 📜 NFT-based certificate ownership
- 🔍 Instant verification system
- 🔐 Tamper-proof credential management
- 📊 Complete certificate lifecycle management

## Files Changed
- `contracts/certificate-platform.clar` - Main smart contract
- `README.md` - Documentation and usage guide

Ready for testing and deployment on Stacks testnet.
