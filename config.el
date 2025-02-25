;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'whiteboard)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
(global-visual-line-mode 1)
(after! consult-gh
  (setq consult-gh-show-preview t)
  (setq consult-gh-repo-action #'consult-gh--repo-browse-files-action)
  (setq consult-gh-default-clone-directory "~/myworks/github/"))
(after! projectile
  (setq projectile-switch-project-action #'dirvish))
;; This would stop tramp working for some hosts
;; https://github.com/doomemacs/doomemacs/issues/6225#issuecomment-1161797450
;; (after! tramp
;;   ;; because I just use git
;;   (setq vc-handled-backends '(Git))
;;   ;; this the original value
;;   (setq vc-ignore-dir-regexp "\\`\\(?:[\\/][\\/][^\\/]+[\\/]\\|/\\(?:net\\|afs\\|\\.\\.\\.\\)/\\)\\'"))
(after! tramp
  (setq shell-file-name "/bin/bash"))
;;(defun watch-variable-change (symbol newval operation where)
;;  "Function to be called when VARIABLE is changed."
;;  (message "Variable %s was changed to %s by %s at %s" symbol newval operation where))
;;(add-variable-watcher 'shell-file-name #'watch-variable-change)
(defun shell-command-at-point ()
  "Execute shell command at point or from selected region."
  (interactive)
  (let* ((rcommand (if (use-region-p)
                       (buffer-substring-no-properties (region-beginning) (region-end))
                     (thing-at-point 'line t)))
         (command (if (string-match ".*:\\s-*\\(.*\\)$" rcommand)
                      (string-trim (match-string 1 rcommand))
                    (string-trim command))))
    (when command
      (async-shell-command command "async"))))
;; accept completion from copilot and fallback to company
(use-package! copilot
  :hook (prog-mode . copilot-mode)
  :bind (:map copilot-completion-map
              ("<tab>" . 'copilot-accept-completion)
              ("TAB" . 'copilot-accept-completion)
              ("C-TAB" . 'copilot-accept-completion-by-word)
              ("C-<tab>" . 'copilot-accept-completion-by-word)))


(defun my/run-2fa-verify-command (output)
  "Detect the OTP verification message and run the 2fa_verify command asynchronously.
The URL and command are dynamically extracted from the buffer."
  (when (string-match "remote: OTP verification is required to access the repository." output)
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward "Use: ssh \\(git@[^ ]+\\) 2fa_verify" nil t)
        (let ((command (concat "ssh " (match-string 1) " 2fa_verify")))
          (async-shell-command command))))))

;; Add the function to `comint-output-filter-functions`
(add-hook 'comint-output-filter-functions 'my/run-2fa-verify-command)

(defun my-handle-otp-verification ()
  "Check the magit-process buffer for OTP verification and
   run the required command."
  (message "Checking for OTP verification...")
  (let ((process-buffer (magit-process-buffer t)))
    (when process-buffer
      (with-current-buffer process-buffer
        (let ((content (buffer-string)))
          ;; Check if the OTP verification message is present
          (when (string-match "Use: \\(ssh git@.*\\)" content)
            (let ((command (match-string 1 content)))
              ;; Execute the extracted command
              (message "Running OTP verification command: %s" command)
              (async-shell-command command))))))))

;; Add the function to the post-refresh hook
(add-hook 'magit-post-refresh-hook 'my-handle-otp-verification)

(defun my-clear-magit-process-buffer (&rest _)
  "Clear the magit-process buffer before setting up a new command."
  (message "Clearing magit-process buffer...")
  (let ((buffer (magit-process-buffer t)))
    (when buffer
      (with-current-buffer buffer
        (let ((inhibit-read-only t))  ;; Temporarily disable read-only mode
          (erase-buffer))))))

;; Advise `magit-process-setup` to clear the buffer before setup
(advice-add 'magit-process-setup :before #'my-clear-magit-process-buffer)
