(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_CERTIFICATE_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_RECIPIENT (err u103))
(define-constant ERR_INSTITUTION_NOT_REGISTERED (err u104))
(define-constant ERR_CERTIFICATE_REVOKED (err u105))

(define-non-fungible-token certificate uint)

(define-data-var next-certificate-id uint u1)

(define-map institutions
  principal
  {
    name: (string-ascii 100),
    verified: bool,
    registration-date: uint
  }
)

(define-map certificates
  uint
  {
    recipient: principal,
    institution: principal,
    certificate-type: (string-ascii 50),
    title: (string-ascii 200),
    issue-date: uint,
    expiry-date: (optional uint),
    metadata-uri: (string-ascii 500),
    revoked: bool
  }
)

(define-map institution-certificates
  {institution: principal, cert-id: uint}
  bool
)

(define-map recipient-certificates
  {recipient: principal, cert-id: uint}
  bool
)

(define-map certificate-verification-codes
  uint
  (string-ascii 64)
)

(define-public (register-institution (name (string-ascii 100)))
  (let ((caller tx-sender))
    (if (is-some (map-get? institutions caller))
      ERR_ALREADY_EXISTS
      (begin
        (map-set institutions caller {
          name: name,
          verified: false,
          registration-date: stacks-block-height
        })
        (ok caller)
      )
    )
  )
)

(define-public (verify-institution (institution principal))
  (if (is-eq tx-sender CONTRACT_OWNER)
    (match (map-get? institutions institution)
      institution-data
      (begin
        (map-set institutions institution (merge institution-data {verified: true}))
        (ok true)
      )
      ERR_INSTITUTION_NOT_REGISTERED
    )
    ERR_NOT_AUTHORIZED
  )
)

(define-public (issue-certificate 
  (recipient principal)
  (certificate-type (string-ascii 50))
  (title (string-ascii 200))
  (expiry-date (optional uint))
  (metadata-uri (string-ascii 500))
  (verification-code (string-ascii 64))
)
  (let (
    (cert-id (var-get next-certificate-id))
    (institution tx-sender)
  )
    (match (map-get? institutions institution)
      institution-data
      (if (get verified institution-data)
        (begin
          (try! (nft-mint? certificate cert-id recipient))
          (map-set certificates cert-id {
            recipient: recipient,
            institution: institution,
            certificate-type: certificate-type,
            title: title,
            issue-date: stacks-block-height,
            expiry-date: expiry-date,
            metadata-uri: metadata-uri,
            revoked: false
          })
          (map-set institution-certificates {institution: institution, cert-id: cert-id} true)
          (map-set recipient-certificates {recipient: recipient, cert-id: cert-id} true)
          (map-set certificate-verification-codes cert-id verification-code)
          (var-set next-certificate-id (+ cert-id u1))
          (ok cert-id)
        )
        ERR_NOT_AUTHORIZED
      )
      ERR_INSTITUTION_NOT_REGISTERED
    )
  )
)

(define-public (revoke-certificate (cert-id uint))
  (let ((institution tx-sender))
    (match (map-get? certificates cert-id)
      cert-data
      (if (is-eq (get institution cert-data) institution)
        (begin
          (map-set certificates cert-id (merge cert-data {revoked: true}))
          (ok true)
        )
        ERR_NOT_AUTHORIZED
      )
      ERR_CERTIFICATE_NOT_FOUND
    )
  )
)

(define-public (transfer-certificate (cert-id uint) (new-owner principal))
  (let ((current-owner tx-sender))
    (match (nft-get-owner? certificate cert-id)
      owner
      (if (is-eq owner current-owner)
        (match (map-get? certificates cert-id)
          cert-data
          (if (not (get revoked cert-data))
            (begin
              (try! (nft-transfer? certificate cert-id current-owner new-owner))
              (map-delete recipient-certificates {recipient: current-owner, cert-id: cert-id})
              (map-set recipient-certificates {recipient: new-owner, cert-id: cert-id} true)
              (map-set certificates cert-id (merge cert-data {recipient: new-owner}))
              (ok true)
            )
            ERR_CERTIFICATE_REVOKED
          )
          ERR_CERTIFICATE_NOT_FOUND
        )
        ERR_NOT_AUTHORIZED
      )
      ERR_CERTIFICATE_NOT_FOUND
    )
  )
)

(define-read-only (get-certificate (cert-id uint))
  (map-get? certificates cert-id)
)

(define-read-only (get-institution (institution principal))
  (map-get? institutions institution)
)

(define-read-only (verify-certificate (cert-id uint) (verification-code (string-ascii 64)))
  (match (map-get? certificate-verification-codes cert-id)
    stored-code
    (and 
      (is-eq stored-code verification-code)
      (match (map-get? certificates cert-id)
        cert-data
        (not (get revoked cert-data))
        false
      )
    )
    false
  )
)

(define-read-only (get-certificate-owner (cert-id uint))
  (nft-get-owner? certificate cert-id)
)

(define-read-only (is-certificate-valid (cert-id uint))
  (match (map-get? certificates cert-id)
    cert-data
    (and
      (not (get revoked cert-data))
      (match (get expiry-date cert-data)
        expiry
        (< stacks-block-height expiry)
        true
      )
    )
    false
  )
)

(define-read-only (get-next-certificate-id)
  (var-get next-certificate-id)
)

(define-read-only (has-certificate (recipient principal) (cert-id uint))
  (default-to false (map-get? recipient-certificates {recipient: recipient, cert-id: cert-id}))
)

(define-read-only (institution-issued-certificate (institution principal) (cert-id uint))
  (default-to false (map-get? institution-certificates {institution: institution, cert-id: cert-id}))
)

(define-read-only (get-certificate-verification-code (cert-id uint))
  (if (is-some (nft-get-owner? certificate cert-id))
    (map-get? certificate-verification-codes cert-id)
    none
  )
)
