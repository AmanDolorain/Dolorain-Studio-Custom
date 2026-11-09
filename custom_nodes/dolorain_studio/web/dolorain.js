import { app } from '../../scripts/app.js';

// Keep the branding in document flow instead of overlaying ComfyUI controls.
app.registerExtension({
  name: 'dolorain.studio.branding',
  setup() {
    if (document.getElementById('dolorain-studio-header')) return;

    const root = document.getElementById('app');
    if (!root) {
      console.warn('[Dolorain Studio] ComfyUI app root not found; header not installed.');
      return;
    }

    const style = document.createElement('style');
    style.id = 'dolorain-studio-style';
    style.textContent = `
      body.dolorain-studio-enabled {
        display: flex !important;
        flex-direction: column !important;
        overflow: hidden !important;
        padding-top: 0 !important;
      }
      body.dolorain-studio-enabled > #app {
        flex: 1 1 auto !important;
        height: calc(100dvh - 42px) !important;
        min-height: 0 !important;
        width: 100% !important;
        overflow: hidden !important;
      }
      #dolorain-studio-header {
        box-sizing: border-box;
        position: relative;
        flex: 0 0 42px;
        width: 100%;
        height: 42px;
        z-index: 1;
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 0 16px;
        background: #15221c;
        color: #f5fff8;
        border-bottom: 1px solid #2e6245;
        font: 600 13px system-ui, sans-serif;
      }
      #dolorain-studio-header .brand-mark {
        width: 9px; height: 9px; border-radius: 50%; background: #4bd58a;
      }
      #dolorain-studio-header .sub {
        margin-left: auto; font-size: 11px; font-weight: 400; color: #b8c9bd;
      }
    `;

    const header = document.createElement('div');
    header.id = 'dolorain-studio-header';
    const mark = document.createElement('span');
    mark.className = 'brand-mark';
    const title = document.createElement('span');
    title.textContent = 'DOLORAIN STUDIO';
    const sub = document.createElement('span');
    sub.className = 'sub';
    sub.textContent = 'Powered by ComfyUI';
    header.append(mark, title, sub);

    document.head.appendChild(style);
    document.body.insertBefore(header, root);
    document.body.classList.add('dolorain-studio-enabled');
  }
});
