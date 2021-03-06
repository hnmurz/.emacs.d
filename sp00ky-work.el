;; Config specific to work.

;; (setq display-buffer-alist 'nil)
;; Might want to make this better: https://emacs.stackexchange.com/questions/12747/how-to-conditionally-reuse-the-current-window-to-display-a-buffer
;;
;; Control where the *Messages* buffer opens
;; (add-to-list 'display-buffer-alist
;;              '("\\*Messages\\*" . ((display-buffer-reuse-window
;;                                     display-buffer-pop-up-window)
;;                                    . ((inhibit-same-window . t)))))

(defvar sp00ky//gdb-cmd-history '())
(defvar sp00ky//gdb-ip-history  '())
(defvar sp00ky//gdb-pid-history '())
(defun sp00ky/gdb-wrapper ()
  "Wrapper function to invoke en-dbg easily. This function will
prompt the user each time for information. I don't expect to be
using it that often, so this is fine."
  (interactive)
  (let* ((input (read-string "Compile Cmd:
1[ax]  - build dir and arch (a=aarch64, x=x86-64)
c      - debug a core file, will prompt for path
d      - clean dbg dir (/localdisk/yocto_debugging/*)
i      - attach to remote, will prompt for ip and pid
Examples: 1a d1a d1xc
: "
                             (car sp00ky//gdb-cmd-history)
                             'sp00ky//gdb-cmd-history
                             sp00ky//gdb-cmd-history
                             nil))
         build-dir build-dir-cmd extra-cmds cmd)
    (setq
     build-dir
     (cond ((string-search "1a" input)
            "/localdisk/hmuresan/yocto/builds/valimar/cn-container-hal-dnx-docker-aarch64")
           ((string-search "1x" input)
            "/localdisk/hmuresan/yocto/builds/valimar/cn-container-hal-dnx-docker-x86-64")
           ((string-search "2a" input)
            "/localdisk/hmuresan/yocto/builds/valimar2/cn-container-hal-dnx-docker-aarch64")
           ((string-search "2x" input)
            "/localdisk/hmuresan/yocto/builds/valimar2/cn-container-hal-dnx-docker-x86-64")
           ((string-search "3a" input)
            "/localdisk/hmuresan/yocto/builds/valimar3/cn-container-hal-dnx-docker-aarch64")
           ((string-search "3x" input)
            "/localdisk/hmuresan/yocto/builds/valimar3/cn-container-hal-dnx-docker-x86-64")
           (t nil)))
    (when build-dir
      (setq build-dir-cmd (concat "--build-dir= " build-dir)))

    ;; Perform any extra actions we need
    (when (string-search "c" input)
      (setq extra-cmds
            (concat "-c "
                    (read-file-name "Location of core file:" "~/from_device/crash/"))))

    (when (string-search "d" input)
      (shell-command "rm -rf /localdisk/yocto_debugging/*"))

    (when (string-search "i" input)
      ;; We will automatically create an extra gdb command file to
      ;; source our local files. This is for the devtooled case. I
      ;; might have to be smarter about this in the future i.e. only
      ;; make the extra commands file in certain scenarios, but for
      ;; now let's leave it with this heuristic
      (delete-file (concat build-dir "/gdb_extra_commands"))
      (with-temp-file (concat build-dir "/gdb_extra_commands")
        (insert (concat "directory "
                        build-dir
                        "/tmp/work/aarch64-evernight-linux/hal-api/1.0.0+git999-r0/image/"))
        (insert (concat "directory "
                        build-dir
                        "/tmp/work/aarch64-evernight-linux/hal-test/1.0.0+git999-r0/image/"))
        (insert (concat "directory "
                        build-dir
                        "/tmp/work/aarch64-evernight-linux/hal/1.0.0+git999-r0/image/")))
      (setq extra-cmds
            (concat
             "--ip "
             (read-string "IP:"
                          (car sp00ky//gdb-ip-history)
                          'sp00ky//gdb-ip-history
                          sp00ky//gdb-ip-history
                          nil)
             " --pid "
             (read-string "PID:" nil
                          'sp00ky//gdb-pid-history
                          sp00ky//gdb-pid-history
                          nil))))

    (setq cmd (concat "gdb_wrapper.sh " build-dir-cmd " " extra-cmds))
    (when (y-or-n-p (concat "Does this command look good?\n\n" cmd "\n\n"))
      (gdb cmd))))

(add-to-list 'display-buffer-alist
             '("\\*Async Shell Command\\*" . (display-buffer-no-window . nil)))

(defun sp00kyWork/copy-to-clipboard (start end)
  "Send text from selected region to port 5556. Note, we are
expecting this port to be port forwarded with something like
\"ssh -R 5556:localhost:5556\""
  (interactive "r")
  (if (use-region-p)
      (let ((tmp-file "/tmp/emacs-clipboard"))
        (write-region start end tmp-file)
        (async-shell-command (concat "cat " (shell-quote-argument tmp-file) " | nc localhost 5556"))
        (evics-kill-ring-save))))
(define-key evics-normal-mode-map (kbd "y") 'sp00kyWork/copy-to-clipboard)

(defun sp00ky/cnfp-dbg-parse-pkt ()
  "Take output from pp vis ppi and make it fit parsepkt. To use,
position cursor on the line after the pasted output."
  (interactive)
  ; Selec lines
  (set-mark-command nil)
  (while (not (looking-at-p "^| Pkt_H"))
    (previous-logical-line))
  ; combine packet to one hex string
  (replace-regexp "|.*?| \\([0-9a-z]*\\).*[\\\n|$]" "\\1" nil (point) (mark))
  (beginning-of-line)
  (insert "cnfp-dbg parsepkt ")
  (end-of-line)
  (insert " noshim")
  ; Copy one liner
  (beginning-of-line)
  (set-mark-command nil)
  (end-of-line 1)
  (sp00kyWork/copy-to-clipboard))

(defun sp00ky/split-tracepoint (start end)
  "Tace a tracepoint and split it. We will deliniate based upon the word before :. For example,
CnCoreSvcAction: Create oam_index: \"\"
Would turn into:
CnCoreSvcAction: Create
oam_index: \"\"
"
  (interactive "r")
  (goto-char start)
  (while (re-search-forward
          " [a-zA-Z]+[a-zA-Z0-9_]*:"
         end
          t)
    (re-search-backward " ")
    (forward-char)
    (newline)))

(defun sp00ky/spartan-to-camel (start end)
  "Remove underscores and capitalize the first letter afterwards within selected region"
  (declare (obsolete string-inflection-camelcase "<2022-07-22 Fri>"))
  (interactive "r")
  (goto-char start)
  (setq-local delete-active-region nil)
  (while (< (point) end)
    (if (= ?_ (char-after))
        (progn
          (delete-forward-char 1)
          (let ((current-char (char-after)))
            (delete-forward-char 1)
            (insert (capitalize current-char)))))
    (forward-char)))

(defun sp00ky/conf-mode-hook ()
  "Config to run when entering conf mode"
  ;; This was a little confusing to figure out. Anyways, it makes the
  ;; char / work as both the first and second char in a comment
  ;; sequence, else it will just be punctuation.
  (modify-syntax-entry ?/ ". 12"))
(add-hook 'conf-unix-mode-hook 'sp00ky/conf-mode-hook)

(defun sp00ky/log-macro-update (start end)
  "In our code we see lines such as:
     CNCORE_LOG( PACKAGE_NAME, LOG_ERR, NULL, \"Invalid virtual mac pointer\" );
We want to update these lines to look more like:
     HAL_LOG_ERR(\"Invalid virtual mac pointer\");
We will have to account for LOG_INFO and LOG_DEBUG accordingly."
  (interactive "r")
  (goto-char start)
  (defvar replacement-string "")
  (while (re-search-forward "CNCORE_LOG[ ]*(" end t)
    (beginning-of-line)
    (cond ((re-search-forward "LOG_INFO" (line-end-position) t)
           (setq replacement-string "HAL_LOG_INFO(\""))
          ((re-search-forward "LOG_ERR" (line-end-position) t)
           (setq replacement-string "HAL_LOG_ERR(\""))
          ((re-search-forward "LOG_DEBUG" (line-end-position) t)
           (setq replacement-string "HAL_LOG_DEBUG(\"")))
    (beginning-of-line)
    (replace-regexp
     "cncore_log.*?\"\\(error:\\|\\)"
     replacement-string
     nil (line-beginning-position) (line-end-position))
    (sp00ky/indent-region-or-paragraph)
    (y-or-n-p "Continue?")))
