#!/bin/sh
# Load Cloud STT transcript modal assets on Call Recordings and expose
# openTranscriptByPublicId for the recordings «Текст» click.
set -e
STT_MOD=/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText
CONF="$STT_MOD/Lib/CloudSpeechToTextConf.php"
if [ ! -f "$CONF" ]; then
  echo "CloudSpeechToTextConf.php missing, skip cdr modal patch"
  exit 0
fi

python3 - <<'PY'
from pathlib import Path

conf = Path("/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText/Lib/CloudSpeechToTextConf.php")
text = conf.read_text(encoding="utf-8")
old = """        if (
            $controller !== 'calldetailrecords'
            || strtolower((string)$dispatcher->getActionName()) !== 'index'
        ) {"""
new = """        if (
            ($controller !== 'calldetailrecords' && $controller !== 'callrecordings')
            || strtolower((string)$dispatcher->getActionName()) !== 'index'
        ) {"""
if "callrecordings" not in text.split("onAfterAssetsPrepared", 1)[-1][:800]:
    if old not in text:
        raise SystemExit("Conf.php controller guard not found")
    conf.write_text(text.replace(old, new, 1), encoding="utf-8")
    print("patched CloudSpeechToTextConf for callrecordings assets")
else:
    print("Conf.php already includes callrecordings")

marker = "openTranscriptByPublicId"
init_old = """    initialize() {
        this.availability = Object.create(null);
        this.pendingLookup = Object.create(null);
        this.$table = $('#cdr-table');
"""
init_new = """    initialize() {
        this.availability = Object.create(null);
        this.pendingLookup = Object.create(null);
        this.lookupUrl = `${this.API_BASE}/cdr-transcript-lookups`;
        this.detailUrl = `${this.API_BASE}/transcripts/`;
        this.exportUrl = `${this.API_BASE}/transcript-exports/`;
        this.deletionUrl = `${this.API_BASE}/transcript-deletions`;
        this.buttonLabel = this.translate('module_cloud_speech_to_text_CdrOpenTranscriptButton');
        this.$table = $('#cdr-table');
"""
init_old_compiled = """    this.availability = Object.create(null);
    this.pendingLookup = Object.create(null);
    this.$table = $('#cdr-table');
    if (this.$table.length === 0 || typeof $.fn.DataTable === 'undefined' || typeof window.MikoCloudSpeechToTextCdr === 'undefined') {
"""
init_new_compiled = """    this.availability = Object.create(null);
    this.pendingLookup = Object.create(null);
    this.lookupUrl = "".concat(this.API_BASE, "/cdr-transcript-lookups");
    this.detailUrl = "".concat(this.API_BASE, "/transcripts/");
    this.exportUrl = "".concat(this.API_BASE, "/transcript-exports/");
    this.deletionUrl = "".concat(this.API_BASE, "/transcript-deletions");
    this.buttonLabel = this.translate('module_cloud_speech_to_text_CdrOpenTranscriptButton');
    this.$table = $('#cdr-table');
    if (this.$table.length === 0 || typeof $.fn.DataTable === 'undefined' || typeof window.MikoCloudSpeechToTextCdr === 'undefined') {
"""
method = """
    openTranscriptByPublicId(callId, publicId, call) {
        if (this.accessDenied || typeof window.MikoCloudSpeechToTextCdr === 'undefined') {
            return false;
        }
        const cid = String(callId || '').trim();
        const pid = String(publicId || '').trim();
        if (cid === '' || pid === '') {
            return false;
        }
        if (!this.availability) {
            this.availability = Object.create(null);
        }
        if (!this.detailUrl) {
            this.detailUrl = `${this.API_BASE}/transcripts/`;
            this.exportUrl = `${this.API_BASE}/transcript-exports/`;
            this.deletionUrl = `${this.API_BASE}/transcript-deletions`;
        }
        this.availability[cid] = pid;
        this.closeModal();
        this.openButton = null;
        this.mountNode = document.createElement('div');
        this.mountNode.id = this.MOUNT_ID;
        this.mountNode.className = 'cstt-cdr-modal-shell module-cloud-speech-to-text-shell';
        document.body.appendChild(this.mountNode);
        window.MikoCloudSpeechToTextCdr.mount(this.mountNode, {
            locale: this.locale(),
            call: call || { date: '', source: '', sourceName: '', destination: '', destinationName: '', duration: '' },
            loadDetail: () => this.loadDetail(pid, cid),
            onExport: (detail, format) => this.exportTranscript(detail, format),
            onDelete: this.canDeleteTranscripts() ? (detail) => this.deleteTranscript(detail, cid) : undefined,
            onClose: () => this.closeModal(),
        });
        return true;
    },

"""
method_compiled = """
  openTranscriptByPublicId: function openTranscriptByPublicId(callId, publicId, call) {
    var _thisRec = this;
    if (this.accessDenied || typeof window.MikoCloudSpeechToTextCdr === 'undefined') {
      return false;
    }
    var cid = String(callId || '').trim();
    var pid = String(publicId || '').trim();
    if (cid === '' || pid === '') {
      return false;
    }
    if (!this.availability) {
      this.availability = Object.create(null);
    }
    if (!this.detailUrl) {
      this.detailUrl = "".concat(this.API_BASE, "/transcripts/");
      this.exportUrl = "".concat(this.API_BASE, "/transcript-exports/");
      this.deletionUrl = "".concat(this.API_BASE, "/transcript-deletions");
    }
    this.availability[cid] = pid;
    this.closeModal();
    this.openButton = null;
    this.mountNode = document.createElement('div');
    this.mountNode.id = this.MOUNT_ID;
    this.mountNode.className = 'cstt-cdr-modal-shell module-cloud-speech-to-text-shell';
    document.body.appendChild(this.mountNode);
    window.MikoCloudSpeechToTextCdr.mount(this.mountNode, {
      locale: this.locale(),
      call: call || { date: '', source: '', sourceName: '', destination: '', destinationName: '', duration: '' },
      loadDetail: function loadDetail() {
        return _thisRec.loadDetail(pid, cid);
      },
      onExport: function onExport(detail, format) {
        return _thisRec.exportTranscript(detail, format);
      },
      onDelete: this.canDeleteTranscripts() ? function (detail) {
        return _thisRec.deleteTranscript(detail, cid);
      } : undefined,
      onClose: function onClose() {
        return _thisRec.closeModal();
      }
    });
    return true;
  },
"""
open_marker = "    openTranscript($button) {"
open_marker_compiled = "  openTranscript: function openTranscript($button) {"

root = Path("/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText")
paths = list(root.rglob("module-cloud-speech-to-text-cdr.js"))
cache = Path("/usr/www/sites/admin-cabinet/assets/js/cache/ModuleCloudSpeechToText")
if cache.exists():
    paths.extend(cache.rglob("module-cloud-speech-to-text-cdr.js"))
seen = set()
for p in paths:
    key = str(p.resolve())
    if key in seen:
        continue
    seen.add(key)
    js = p.read_text(encoding="utf-8")
    changed = False
    if init_old in js:
        js = js.replace(init_old, init_new, 1)
        changed = True
    if init_old_compiled in js:
        js = js.replace(init_old_compiled, init_new_compiled, 1)
        changed = True
    if marker not in js:
        if open_marker in js:
            js = js.replace(open_marker, method + open_marker, 1)
            changed = True
        elif open_marker_compiled in js:
            js = js.replace(open_marker_compiled, method_compiled + open_marker_compiled, 1)
            changed = True
        else:
            print("skip (no openTranscript):", p)
            continue
    if changed:
        p.write_text(js, encoding="utf-8")
        print("patched", p)
    else:
        print("already patched", p)
PY

echo "cdr modal recordings patch done"
