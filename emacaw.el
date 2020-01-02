
(size-indication-mode t)

(defun tweet ()
  "Send a tweet!"
  (interactive)
  (hmac-sha1 "foo" "bar")
  (if (<= (buffer-size) 140)
      (send-tweet 
       (buffer-substring-no-properties 1 (buffer-size))
       )
    (print "MORE THAN 140 CHARS!"))
   )
  
(defun keep-output (process output)
  (print output))

(defun send-tweet (tweet-body)
  (setq conn (open-network-stream "tweet" nil  "127.0.0.1" 8000))
  (set-process-filter conn 'keep-output)
  (process-send-string conn "GET /library.csv\n\n")

 
  )


(defun escape-uri (x)
  (url-hexify-string x))



(defun encode-parameters (parameters)
  (mapcar
   (lambda (parameter)
     (cons
      (escape-uri (car parameter))
      (escape-uri (cdr parameter))
      )
     )  parameters))



(defun create-parameter-string (parameters)
  (setq encoded-parameters  (encode-parameters parameters))
  (setq sorted-encoded-parameters
	(sort encoded-parameters
	      (lambda (a b)
		(string< (car a) (car b)))))

  (mapconcat
   (lambda (y)
     (concat (car y) "=" (cdr y))
     ) sorted-encoded-parameters  "&"))




(defun create-signature-base-string (parameter-string  url http-method)
  (concat (upcase http-method)  "&" (escape-uri url) "&" (escape-uri parameter-string)))

(defun get-signing-key(consumer-secret oauth-token-secret)
  (concat (escape-uri consumer-secret) "&"  (escape-uri oauth-token-secret)))

(defun zipxor (a b acc)
  "Apply `logxor' to each element of list a and list b `(logxor a b) returning a list of the xor'd values."
  (if (= (length a) 0)
      acc
    (setq new-acc (append acc (cons (logxor (car a) (car b)) '())))
    (zipxor (cdr a) (cdr b) new-acc)))


(defun bytepad(origin width padbyte)
  "Pad the origin string to the width parameter using the supplied padbyte. 
For example `(bytepad \"foo\" 10 #x42)' would return the string `\"fooBBBBBBB\"'"
  (while (< (length origin) width)
    (setq origin (concat origin (byte-to-string padbyte))))
  origin)



(defun coerce (putative-binary)
  "These should be unecessary and seems like a no-op, but fuck Elisp."
  (base64-decode-string (base64-encode-string putative-binary)))


(defun hmac-sha1 (key message)
  "Generate a HMAC-SHA1 message authentication code for a given `key' and `message'. Returns a hexadecimal-encoded string of the MAC."
  (setq block-size 64) 
  (setq output-size 20)

  
  (if (> (length key) block-size)
      (setq key (concat "" (secure-hash 'sha1 key nil nil "t"))))
  
  (if (< (length key) block-size)
      (setq key (bytepad key block-size #x00)))

  
  
  (setq o-key-pad  (zipxor (string-to-list key) (string-to-list (bytepad "" block-size #x5c)) '()))
  
  (setq i-key-pad (zipxor (string-to-list key) (string-to-list (bytepad "" block-size #x36)) '()))

  
  (secure-hash 'sha1
	       (coerce (concat "" o-key-pad
			       (secure-hash 'sha1
					    (coerce (concat "" i-key-pad  message)) nil nil "t")))))

(defun sign (parameters url consumer-secret oauth-token-secret http-method)
  (setq parameter-string  (create-parameter-string parameters))
  (setq signature-base-string (create-signature-base-string parameter-string  url  http-method))
  (setq signing-key (get-signing-key consumer-secret  oauth-token-secret))
  (hmac-sha1 signing-key signature-base-string))




;; UNIT TESTS
(require 'ert)

(defun get-test-parameters ()
  '(("include_entities" .  "true")
  ("status" . "Hello Ladies + Gentlemen, a signed OAuth request!")
  ("oauth_consumer_key" ."xvz1evFS4wEEPTGEFPHBog")
  ("oauth_nonce". "kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg")
  ("oauth_signature_method" . "HMAC-SHA1")
  ("oauth_timestamp" . "1318622958")
  ("oauth_token" . "370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb")
  ("oauth_version" . "1.0")))

(ert-deftest emacaw-test-escape-uri ()
  "Tests the conversion of a string to a URL encoded string."
  (should
   (equal
    (escape-uri "Hello Ladies + Gentlemen, a signed OAuth request!")
    "Hello%20Ladies%20%2B%20Gentlemen%2C%20a%20signed%20OAuth%20request%21")))
	
(ert-deftest emacaw-test-create-parameter-string ()
  "Tests the creation of a paramter string from an alist of parameters"
  (should
   (equal
    (create-parameter-string (get-test-parameters))
    "include_entities=true&oauth_consumer_key=xvz1evFS4wEEPTGEFPHBog&oauth_nonce=kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg&oauth_signature_method=HMAC-SHA1&oauth_timestamp=1318622958&oauth_token=370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb&oauth_version=1.0&status=Hello%20Ladies%20%2B%20Gentlemen%2C%20a%20signed%20OAuth%20request%21")))


(ert-deftest emacaw-test-create-signature-base ()
  "Tests the composition of the signature base string for OAuth."
  (should
   (equal
    (create-signature-base-string (create-parameter-string (get-test-parameters)) "https://api.twitter.com/1/statuses/update.json" "post")
    "POST&https%3A%2F%2Fapi.twitter.com%2F1%2Fstatuses%2Fupdate.json&include_entities%3Dtrue%26oauth_consumer_key%3Dxvz1evFS4wEEPTGEFPHBog%26oauth_nonce%3DkYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D1318622958%26oauth_token%3D370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb%26oauth_version%3D1.0%26status%3DHello%2520Ladies%2520%252B%2520Gentlemen%252C%2520a%2520signed%2520OAuth%2520request%2521")))


(ert-deftest emacaw-test-get-signing-key ()
  "Tests the concatenation and creation of the signing key from it's constotuent parts."
  (should
   (equal
    (get-signing-key "kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw" "LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE")
    "kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw&LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE")))

(ert-deftest emcaw-test-hmac-sha1-zero-length-message ()
  "Tests the bespoke HMAC-SHA1 inadvisably implemented in this extension,"
  (should
   (equal
    (hmac-sha1 "key" "")
    "f42bb0eeb018ebbd4597ae7213711ec60760843f" ))) 


(ert-deftest emcaw-test-hmac-sha1-simple-key-message-001()
  "Tests the bespoke HMAC-SHA1 inadvisably implemented in this extension,"
  (should
   (equal
    (hmac-sha1 "bar" "foo")
    "85d155c55ed286a300bd1cf124de08d87e914f3a" )))

(ert-deftest emcaw-test-hmac-sha1-simple-key-message-002 ()
  "Tests the bespoke HMAC-SHA1 inadvisably implemented in this extension,"
  (should
   (equal
    (hmac-sha1 "key" "The quick brown fox jumps over the lazy dog")
    "de7c9b85b8b78aa6bc8a7a36f70a90701c9db4d9" )))

(ert-deftest emcaw-test-hmac-sha1-message-larger-than-block-size ()
  "Tests the bespoke HMAC-SHA1 inadvisably implemented in this extension,"
  (should
   (equal
    (hmac-sha1 "key" "In cryptography, an HMAC (sometimes expanded as either keyed-hash message authentication code or hash-based message authentication code) is a specific type of message authentication code (MAC) involving a cryptographic hash function and a secret cryptographic key. It may be used to simultaneously verify both the data integrity and the authenticity of a message, as with any MAC. Any cryptographic hash function, such as SHA-256 or SHA-3, may be used in the calculation of an HMAC; the resulting MAC algorithm is termed HMAC-X, where X is the hash function used (e.g. HMAC-SHA256 or HMAC-SHA3). The cryptographic strength of the HMAC depends upon the cryptographic strength of the underlying hash function, the size of its hash output, and the size and quality of the key.")
    "ae46438aada90b8d2b35ad2a7344925805457621" )))


(ert-deftest emcaw-test-hmac-sha1-key-larger-than-block-size ()
  "Tests the bespoke HMAC-SHA1 inadvisably implemented in this extension,"
  (should
   (equal
    (hmac-sha1 "0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33MGJlZWM3YjVlYTNmMGZkYmM5NWQwZGQ0N2YzYzViYzI3NWRhOGEzMw==" "The quick brown fox jumps over the lazy dog")
    "e4db689e83caef6c1d3520aa4a1eaf4b83e54f89" )))


(ert-deftest emacaw-test-sign ()
  "Tests a full sign of request components."
  (should
   (equal
    (sign (get-test-parameters) "https://api.twitter.com/1/statuses/update.json"  "kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw" "LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE" "post")
    "b679c0af18f4e9c587ab8e200acd4e48a93f8cb6")))


   
