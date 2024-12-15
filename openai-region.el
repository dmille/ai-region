;;; openai-region.el --- Transform selected text in context with OpenAI -*- lexical-binding: t; -*-

;; Author: Your Name <you@example.com>
;; Version: 0.3
;; Keywords: tools, convenience, ai
;; URL: https://example.com/openai-region
;; Package-Requires: ((emacs "26.1"))

;;; Commentary:
;;
;; This package defines a command that:
;; - Takes the entire buffer as context
;; - Marks the selected region between <<<START>>> and <<<END>>>
;; - Prompts the user for instructions
;; - Sends the entire buffer (with markers) to the OpenAI Chat Completion endpoint
;; - Returns only the transformed code snippet for the marked region.
;;
;; The rest of the file is only for context and should not be changed or returned.
;; The assistant returns only the transformed region in triple backticks.

;;; Code:

(require 'json)
(require 'url)

(defvar openai-region-model "gpt-3.5-turbo"
  "Default OpenAI model to use.")

(defvar openai-region-api-url "https://api.openai.com/v1/chat/completions"
  "The OpenAI Chat Completion endpoint.")

(defvar openai-region-api-key (getenv "OPENAI_API_KEY")
  "Your OpenAI API key. Must be set in environment or Emacs before using this command.")

(defun openai-region--post-request (url data callback)
  "Send a synchronous POST request to URL with JSON-encoded DATA, then call CALLBACK with the parsed JSON."
  (let* ((url-request-method "POST")
         (url-request-extra-headers `(("Content-Type" . "application/json")
                                      ("Authorization" . ,(concat "Bearer " openai-region-api-key))))
         (url-request-data (encode-coding-string (json-encode data) 'utf-8))
         (buffer (url-retrieve-synchronously url t)))
    (unless buffer
      (error "Failed to get a response from OpenAI API"))
    (with-current-buffer buffer
      (goto-char (point-min))
      ;; Move to JSON response
      (re-search-forward "^$")
      (let ((json-object-type 'alist)
            (json-array-type 'list)
            (json-key-type 'string))
        (let ((response (json-parse-buffer :object-type 'alist)))
          (kill-buffer buffer)
          (funcall callback response))))))

(defun openai-region--extract-code (content)
  "Extract code from triple backticks in CONTENT.
If triple backticks are found, return only that section. Otherwise, return CONTENT as-is."
  (if (string-match "```\\(?:[[:alpha:]]+\\)?\n?\\(.*?\\)```" content)
      (match-string 1 content)
    content))

(defun openai-region-transform (prompt full-buffer selection-start selection-end)
  "Send PROMPT and FULL-BUFFER with a marked selection to the OpenAI API and return only transformed code."
  (let* ((before (substring full-buffer 0 selection-start))
         (selected (substring full-buffer selection-start selection-end))
         (after (substring full-buffer selection-end))
         (marked-buffer (concat before
                                "\n<<<START>>>\n"
                                selected
                                "\n<<<END>>>\n"
                                after)))
    (openai-region--post-request
     openai-region-api-url
     `(("model" . ,openai-region-model)
       ("messages" .
        [(("role" . "system") 
          ("content" . "You are a helpful assistant. You have been given the entire file as context. Within the file, a region is marked between <<<START>>> and <<<END>>>. The user wants to transform ONLY that region based on their instructions. You must return ONLY the transformed code snippet for that region in triple backticks, and nothing else. Do not include the rest of the file in your response. Do not include explanations. Do not return anything outside the triple backticks."))
         (("role" . "user")
          ("content" . ,(concat 
                         prompt
                         "\n\nBelow is the entire file for context. The region that should be transformed is marked between <<<START>>> and <<<END>>>.\n\n"
                         "```file\n"
                         marked-buffer
                         "\n```\n"
                         "Please return only the transformed snippet between those markers, enclosed in triple backticks, and do not modify or return any code outside that region.")))])
       ("temperature" . 0))
     (lambda (response)
       (let* ((choices (alist-get "choices" response))
              (first-choice (car choices))
              (message (alist-get "message" first-choice))
              (content (alist-get "content" message))
              (code (openai-region--extract-code content)))
         (or code (error "No content returned by OpenAI API"))))))


;;;###autoload
(defun openai-transform-region (start end)
  "Prompt for instructions, send entire file to OpenAI with the region marked, and replace it with the transformed code."
  (interactive "r")
  (unless openai-region-api-key
    (error "OPENAI_API_KEY not set. Please set it before using this command."))
  (let* ((prompt (read-string "Describe what you want to do with the selected code: "))
         (full-buffer (buffer-substring-no-properties (point-min) (point-max)))
         (result (openai-region-transform prompt full-buffer start end)))
    (delete-region start end)
    (insert result)))

(provide 'openai-region)

;;; openai-region.el ends here
