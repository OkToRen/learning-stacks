;; title: message-board
;; version:
;; summary:
;; description:
;;
;; Changes:
;; - Converted file line-endings from CRLF to LF (Clarity parser only supports LF)
;; - Replaced Clarity 4 features (restrict-assets?, with-ft, current-contract)
;;   with Clarity 3 equivalents since the current Clarinet SDK does not support Clarity 4
;; - Fixed get-stacks-block-info? to use single keyword 'id-header-hash' (2-arg form)

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

;; Define contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Define error codes
(define-constant ERR_NOT_ENOUGH_SBTC (err u1004))
(define-constant ERR_NOT_CONTRACT_OWNER (err u1005))
(define-constant ERR_BLOCK_NOT_FOUND (err u1003))

;; Define a map to store messages
;; Each message has an ID, content, author and Bitcoin block height timestamp
(define-map messages 
    uint 
    { 
        message: (string-utf8 280),
        author: principal,
        time: uint, 
    }
)

;; Counter for total messages
(define-data-var message-count uint u0)

;; Public function to add a new message for 1 satoshi of sBTC
;; @format-ignore
(define-public (add-message (content (string-utf8 280)))
    (let ((id (+ (var-get message-count) u1)))
        ;; Charge 1 satoshi of sBTC from the caller
        ;; Note: Uses (as-contract tx-sender) to reference the contract's own principal
        ;; instead of Clarity 4's 'current-contract' keyword
        (unwrap! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
            transfer u1 contract-caller (as-contract tx-sender) none
        ) ERR_NOT_ENOUGH_SBTC)
        ;; Store the message with current Bitcoin block height
        (map-set messages id {
            message: content,
            author: contract-caller,
            time: burn-block-height,
        })
        ;; Update message count
        (var-set message-count id)
        ;; Emit event for the new message
        (print {
            event: "[Stacks Dev Quickstart] New Message",
            message: content,
            id: id,
            author: contract-caller,
            time: burn-block-height,
        })
        ;; Return the message ID
        (ok id)
    )
)

;; Withdraw function for contract owner to withdraw accumulated sBTC
(define-public (withdraw-funds)
    (begin 
     (asserts! (is-eq tx-sender CONTRACT_OWNER) (err u1005))
     ;; Note: (as-contract tx-sender) returns the contract's principal for get-balance
     ;; The transfer is wrapped in (as-contract ...) so tx-sender becomes the contract,
     ;; allowing it to send its own funds to CONTRACT_OWNER
     (let ((balance (unwrap-panic (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token 
            get-balance (as-contract tx-sender)
        ))))
            (if (> balance u0)
                (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
                    transfer balance tx-sender CONTRACT_OWNER none
                ))
                (ok false)    
            )
        )
    )
)

(define-read-only (get-message (id uint)) 
    (map-get? messages id)
)

(define-read-only (get-message-author (id uint))
    (get author (map-get? messages id))
)

(define-read-only (get-message-count-at-block (block uint)) 
    (ok (at-block      
        (unwrap! (get-stacks-block-info? id-header-hash block) ERR_BLOCK_NOT_FOUND)
        (var-get message-count)
    ))
)