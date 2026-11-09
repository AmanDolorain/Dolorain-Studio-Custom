import { app } from '../../scripts/app.js';

app.registerExtension({
  name: 'dolorain.studio.branding',
  setup() {
    if (document.getElementById('dolorain-studio-header')) return;
    const style = document.createElement('style');
    style.id = 'dolorain-studio-style';
    style.textContent = `
      #dolorain-studio-header { box-sizing:border-box; position:fixed; top:0;left:0;right:0; height:42px; z-index:10000; display:flex; align-items:center; gap:12px; padding:0 16px; background:#15221c; color:#f5fff8; border-bottom:1px solid #2e6245; font:600 13px system-ui,sans-serif; }
      #dolorain-studio-header .brand-mark { width:9px;height:9px;border-radius:50%;background:#4bd58a; }
      #dolorain-studio-header .sub { margin-left:auto; font-size:11px; font-weight:400; color:#b8c9bd; }
      body { padding-top:42px !important; }
    `;
    document.head.appendChild(style);
    const header = document.createElement('div');
    header.id = 'dolorain-studio-header';
    const mark = document.createElement('span'); mark.className = 'brand-mark';
    const title = document.createElement('span'); title.textContent = 'DOLORAIN STUDIO';
    const sub = document.createElement('span'); sub.className = 'sub'; sub.textContent = 'Powered by ComfyUI';
    header.append(mark,title,sub);
    document.body.appendChild(header);
  }
});
