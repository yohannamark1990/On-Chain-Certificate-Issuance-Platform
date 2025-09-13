(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_CERTIFICATE_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_RECIPIENT (err u103))
(define-constant ERR_INSTITUTION_NOT_REGISTERED (err u104))
(define-constant ERR_CERTIFICATE_REVOKED (err u105))

(define-constant ERR_TEMPLATE_NOT_FOUND (err u200))
(define-constant ERR_TEMPLATE_ALREADY_EXISTS (err u201))
(define-constant ERR_TEMPLATE_INACTIVE (err u202))

(define-data-var next-template-id uint u1)

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

(define-map batch-operations
  uint 
  {
    institution: principal,
    certificate-ids: (list 50 uint),
    operation-date: uint,
    batch-type: (string-ascii 20)
  }
)

(define-data-var next-batch-id uint u1)

(define-public (batch-issue-certificates 
  (recipients (list 10 principal))
  (certificate-types (list 10 (string-ascii 50)))
  (titles (list 10 (string-ascii 200)))
  (expiry-dates (list 10 (optional uint)))
  (metadata-uris (list 10 (string-ascii 500)))
  (verification-codes (list 10 (string-ascii 64)))
)
  (let (
    (institution tx-sender)
    (batch-id (var-get next-batch-id))
  )
    (match (map-get? institutions institution)
      institution-data
      (if (get verified institution-data)
        (let ((result (fold batch-process-cert-data 
          (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9)
          {success: true, cert-ids: (list), recipients: recipients, 
           types: certificate-types, titles: titles, expiry-dates: expiry-dates,
           metadata-uris: metadata-uris, verification-codes: verification-codes})))
          (if (get success result)
            (begin
              (map-set batch-operations batch-id {
                institution: institution,
                certificate-ids: (get cert-ids result),
                operation-date: stacks-block-height,
                batch-type: "issue"
              })
              (var-set next-batch-id (+ batch-id u1))
              (ok {batch-id: batch-id, certificate-ids: (get cert-ids result)})
            )
            (err u106)
          )
        )
        ERR_NOT_AUTHORIZED
      )
      ERR_INSTITUTION_NOT_REGISTERED
    )
  )
)

(define-private (batch-process-cert-data 
  (index uint)
  (acc {success: bool, cert-ids: (list 50 uint), recipients: (list 10 principal),
        types: (list 10 (string-ascii 50)), titles: (list 10 (string-ascii 200)),
        expiry-dates: (list 10 (optional uint)), metadata-uris: (list 10 (string-ascii 500)),
        verification-codes: (list 10 (string-ascii 64))})
)
  (if (and (get success acc) (< index (len (get recipients acc))))
    (let ((cert-id (var-get next-certificate-id)))
      (match (element-at (get recipients acc) index)
        recipient
        (match (nft-mint? certificate cert-id recipient)
          success
          (begin
            (map-set certificates cert-id {
              recipient: recipient,
              institution: tx-sender,
              certificate-type: (default-to "" (element-at (get types acc) index)),
              title: (default-to "" (element-at (get titles acc) index)),
              issue-date: stacks-block-height,
              expiry-date: (default-to none (element-at (get expiry-dates acc) index)),
              metadata-uri: (default-to "" (element-at (get metadata-uris acc) index)),
              revoked: false
            })
            (map-set institution-certificates {institution: tx-sender, cert-id: cert-id} true)
            (map-set recipient-certificates {recipient: recipient, cert-id: cert-id} true)
            (map-set certificate-verification-codes cert-id 
              (default-to "" (element-at (get verification-codes acc) index)))
            (var-set next-certificate-id (+ cert-id u1))
            (merge acc {cert-ids: (unwrap-panic (as-max-len? (append (get cert-ids acc) cert-id) u50))})
          )
          error
          (merge acc {success: false})
        )
        (merge acc {success: false})
      )
    )
    acc
  )
)

(define-read-only (get-batch-operation (batch-id uint))
  (map-get? batch-operations batch-id)
)

(define-read-only (get-recipient-certificate-count (recipient principal))
  (let ((max-id (var-get next-certificate-id)))
    (fold count-recipient-certs 
      (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 
            u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40
            u41 u42 u43 u44 u45 u46 u47 u48 u49 u50)
      {count: u0, recipient: recipient, max-id: max-id})))

(define-private (count-recipient-certs (cert-id uint) (acc {count: uint, recipient: principal, max-id: uint}))
  (if (< cert-id (get max-id acc))
    (if (has-certificate (get recipient acc) cert-id)
      {count: (+ (get count acc) u1), recipient: (get recipient acc), max-id: (get max-id acc)}
      acc)
    acc))

(define-read-only (get-institution-certificate-count (institution principal))
  (let ((max-id (var-get next-certificate-id)))
    (get count (fold count-institution-certs 
      (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 
            u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40
            u41 u42 u43 u44 u45 u46 u47 u48 u49 u50)
      {count: u0, institution: institution, max-id: max-id}))))

(define-private (count-institution-certs (cert-id uint) (acc {count: uint, institution: principal, max-id: uint}))
  (if (< cert-id (get max-id acc))
    (if (institution-issued-certificate (get institution acc) cert-id)
      {count: (+ (get count acc) u1), institution: (get institution acc), max-id: (get max-id acc)}
      acc)
    acc))


(define-map certificate-templates
  uint
  {
    institution: principal,
    template-name: (string-ascii 100),
    certificate-type: (string-ascii 50),
    title-prefix: (string-ascii 150),
    default-expiry-period: (optional uint),
    metadata-template: (string-ascii 400),
    active: bool,
    creation-date: uint,
    usage-count: uint
  }
)

(define-map institution-templates
  {institution: principal, template-id: uint}
  bool
)

(define-public (create-certificate-template
  (template-name (string-ascii 100))
  (certificate-type (string-ascii 50))
  (title-prefix (string-ascii 150))
  (default-expiry-period (optional uint))
  (metadata-template (string-ascii 400))
)
  (let (
    (template-id (var-get next-template-id))
    (institution tx-sender)
  )
    (match (map-get? institutions institution)
      institution-data
      (if (get verified institution-data)
        (begin
          (map-set certificate-templates template-id {
            institution: institution,
            template-name: template-name,
            certificate-type: certificate-type,
            title-prefix: title-prefix,
            default-expiry-period: default-expiry-period,
            metadata-template: metadata-template,
            active: true,
            creation-date: stacks-block-height,
            usage-count: u0
          })
          (map-set institution-templates {institution: institution, template-id: template-id} true)
          (var-set next-template-id (+ template-id u1))
          (ok template-id)
        )
        ERR_NOT_AUTHORIZED
      )
      ERR_INSTITUTION_NOT_REGISTERED
    )
  )
)

(define-public (issue-certificate-from-template
  (template-id uint)
  (recipient principal)
  (title-suffix (string-ascii 50))
  (custom-expiry (optional uint))
  (verification-code (string-ascii 64))
)
  (let ((institution tx-sender))
    (match (map-get? certificate-templates template-id)
      template-data
      (if (and 
           (is-eq (get institution template-data) institution)
           (get active template-data))
        (let (
          (cert-id (var-get next-certificate-id))
          (full-title (concat (get title-prefix template-data) title-suffix))
          (final-expiry (match custom-expiry
            custom (some custom)
            (match (get default-expiry-period template-data)
              default-period (some (+ stacks-block-height default-period))
              none)))
        )
          (try! (nft-mint? certificate cert-id recipient))
          (map-set certificates cert-id {
            recipient: recipient,
            institution: institution,
            certificate-type: (get certificate-type template-data),
            title: full-title,
            issue-date: stacks-block-height,
            expiry-date: final-expiry,
            metadata-uri: (get metadata-template template-data),
            revoked: false
          })
          (map-set institution-certificates {institution: institution, cert-id: cert-id} true)
          (map-set recipient-certificates {recipient: recipient, cert-id: cert-id} true)
          (map-set certificate-verification-codes cert-id verification-code)
          (map-set certificate-templates template-id 
            (merge template-data {usage-count: (+ (get usage-count template-data) u1)}))
          (var-set next-certificate-id (+ cert-id u1))
          (ok cert-id)
        )
        (if (get active template-data)
          ERR_NOT_AUTHORIZED
          ERR_TEMPLATE_INACTIVE)
      )
      ERR_TEMPLATE_NOT_FOUND
    )
  )
)

(define-public (toggle-template-status (template-id uint))
  (let ((institution tx-sender))
    (match (map-get? certificate-templates template-id)
      template-data
      (if (is-eq (get institution template-data) institution)
        (begin
          (map-set certificate-templates template-id 
            (merge template-data {active: (not (get active template-data))}))
          (ok (not (get active template-data)))
        )
        ERR_NOT_AUTHORIZED
      )
      ERR_TEMPLATE_NOT_FOUND
    )
  )
)

(define-read-only (get-certificate-template (template-id uint))
  (map-get? certificate-templates template-id)
)

(define-read-only (get-institution-template-count (institution principal))
  (let ((max-id (var-get next-template-id)))
    (get count (fold count-institution-templates
      (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20)
      {count: u0, institution: institution, max-id: max-id}))))

(define-private (count-institution-templates 
  (template-id uint) 
  (acc {count: uint, institution: principal, max-id: uint})
)
  (if (< template-id (get max-id acc))
    (if (default-to false (map-get? institution-templates 
          {institution: (get institution acc), template-id: template-id}))
      {count: (+ (get count acc) u1), institution: (get institution acc), max-id: (get max-id acc)}
      acc)
    acc))

(define-read-only (get-next-template-id)
  (var-get next-template-id)
)


(define-constant ERR_ACHIEVEMENT_NOT_FOUND (err u300))
(define-constant ERR_ACHIEVEMENT_ALREADY_EARNED (err u301))

(define-data-var next-achievement-id uint u1)

(define-map achievement-definitions
  uint
  {
    name: (string-ascii 100),
    description: (string-ascii 200),
    achievement-type: (string-ascii 30),
    threshold: uint,
    active: bool
  }
)

(define-map user-achievements
  {user: principal, achievement-id: uint}
  {
    earned-date: uint,
    progress: uint,
    completed: bool
  }
)

(define-map achievement-progress
  {user: principal, metric: (string-ascii 30)}
  uint
)

(define-public (create-achievement
  (name (string-ascii 100))
  (description (string-ascii 200))
  (achievement-type (string-ascii 30))
  (threshold uint)
)
  (let ((achievement-id (var-get next-achievement-id)))
    (if (is-eq tx-sender CONTRACT_OWNER)
      (begin
        (map-set achievement-definitions achievement-id {
          name: name,
          description: description,
          achievement-type: achievement-type,
          threshold: threshold,
          active: true
        })
        (var-set next-achievement-id (+ achievement-id u1))
        (ok achievement-id)
      )
      ERR_NOT_AUTHORIZED
    )
  )
)

(define-public (update-progress (user principal) (metric (string-ascii 30)) (increment uint))
  (let ((new-progress (+ (default-to u0 (map-get? achievement-progress {user: user, metric: metric})) increment)))
    (begin
      (map-set achievement-progress {user: user, metric: metric} new-progress)
      (check-achievements user metric new-progress)
      (ok new-progress)
    )
  )
)

(define-private (check-achievements (user principal) (metric (string-ascii 30)) (progress uint))
  (let ((achievement-ids (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)))
    (fold check-single-achievement achievement-ids {user: user, metric: metric, progress: progress, success: true})
    true
  )
)

(define-private (check-single-achievement 
  (achievement-id uint)
  (acc {user: principal, metric: (string-ascii 30), progress: uint, success: bool})
)
  (match (map-get? achievement-definitions achievement-id)
    achievement-data
    (if (and 
         (get active achievement-data)
         (is-eq (get achievement-type achievement-data) (get metric acc))
         (>= (get progress acc) (get threshold achievement-data)))
      (let ((user-key {user: (get user acc), achievement-id: achievement-id}))
        (if (is-none (map-get? user-achievements user-key))
          (begin
            (map-set user-achievements user-key {
              earned-date: stacks-block-height,
              progress: (get progress acc),
              completed: true
            })
            acc
          )
          acc
        )
      )
      acc
    )
    acc
  )
)

(define-read-only (get-achievement (achievement-id uint))
  (map-get? achievement-definitions achievement-id)
)

(define-read-only (get-user-achievement (user principal) (achievement-id uint))
  (map-get? user-achievements {user: user, achievement-id: achievement-id})
)

(define-read-only (get-user-progress (user principal) (metric (string-ascii 30)))
  (default-to u0 (map-get? achievement-progress {user: user, metric: metric}))
)

(define-read-only (get-user-achievement-count (user principal))
  (let ((achievement-ids (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)))
    (get count (fold count-user-achievements achievement-ids {user: user, count: u0}))
  )
)

(define-private (count-user-achievements 
  (achievement-id uint) 
  (acc {user: principal, count: uint})
)
  (if (is-some (map-get? user-achievements {user: (get user acc), achievement-id: achievement-id}))
    {user: (get user acc), count: (+ (get count acc) u1)}
    acc
  )
)