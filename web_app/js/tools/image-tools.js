// ============================================================
// FileWorks — Image Tools (browser Canvas API)
// ============================================================

const ImageTools = {
  SUPPORTED: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'],

  // ---- Decode image into HTMLImageElement ----
  async _loadImage(file) {
    const dataUrl = await FW.file.readAsDataURL(file);
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = () => reject(new Error(`Cannot decode image: ${file.name}`));
      img.src = dataUrl;
    });
  },

  // ---- Compress Image ----
  async compress(file, quality = 0.82, outputFormat = null) {
    const ext = (file.name.split('.').pop() || 'jpg').toLowerCase();
    const format = outputFormat || (ext === 'png' ? 'image/png' : 'image/jpeg');
    const q = format === 'image/png' ? undefined : Math.min(1, Math.max(0.01, quality));

    const img = await this._loadImage(file);
    const canvas = document.createElement('canvas');
    canvas.width = img.naturalWidth;
    canvas.height = img.naturalHeight;
    const ctx = canvas.getContext('2d');
    if (format === 'image/jpeg') {
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
    }
    ctx.drawImage(img, 0, 0);

    const blob = await new Promise(resolve => canvas.toBlob(resolve, format, q));
    canvas.width = 0; canvas.height = 0;
    const outExt = format === 'image/png' ? 'png' : format === 'image/webp' ? 'webp' : 'jpg';
    const baseName = file.name.replace(/\.[^.]+$/, '');
    return { blob, name: `${baseName}_compressed.${outExt}` };
  },

  // ---- Resize Image ----
  async resize(file, targetWidth, targetHeight, maintainAspect = true, outputFormat = null) {
    const ext = (file.name.split('.').pop() || 'jpg').toLowerCase();
    const format = outputFormat || (ext === 'png' ? 'image/png' : 'image/jpeg');

    const img = await this._loadImage(file);
    let w = targetWidth || img.naturalWidth;
    let h = targetHeight || img.naturalHeight;

    if (maintainAspect) {
      const aspectRatio = img.naturalWidth / img.naturalHeight;
      if (targetWidth && !targetHeight) {
        h = Math.round(targetWidth / aspectRatio);
      } else if (targetHeight && !targetWidth) {
        w = Math.round(targetHeight * aspectRatio);
      } else if (targetWidth && targetHeight) {
        const scaleW = targetWidth / img.naturalWidth;
        const scaleH = targetHeight / img.naturalHeight;
        const scale = Math.min(scaleW, scaleH);
        w = Math.round(img.naturalWidth * scale);
        h = Math.round(img.naturalHeight * scale);
      }
    }

    w = Math.max(1, w);
    h = Math.max(1, h);

    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d');
    if (format === 'image/jpeg') {
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, w, h);
    }
    ctx.drawImage(img, 0, 0, w, h);

    const q = format === 'image/png' ? undefined : 0.9;
    const blob = await new Promise(resolve => canvas.toBlob(resolve, format, q));
    canvas.width = 0; canvas.height = 0;
    const outExt = format === 'image/png' ? 'png' : format === 'image/webp' ? 'webp' : 'jpg';
    const baseName = file.name.replace(/\.[^.]+$/, '');
    return { blob, name: `${baseName}_${w}x${h}.${outExt}` };
  },

  // ---- Convert Format ----
  async convert(file, targetFormat) {
    // targetFormat: 'jpg', 'png', 'webp'
    const mimeMap = { jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp' };
    const mime = mimeMap[targetFormat] || 'image/jpeg';

    const img = await this._loadImage(file);
    const canvas = document.createElement('canvas');
    canvas.width = img.naturalWidth;
    canvas.height = img.naturalHeight;
    const ctx = canvas.getContext('2d');
    if (mime === 'image/jpeg') {
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
    }
    ctx.drawImage(img, 0, 0);

    const q = mime === 'image/png' ? undefined : 0.92;
    const blob = await new Promise(resolve => canvas.toBlob(resolve, mime, q));
    canvas.width = 0; canvas.height = 0;
    const baseName = file.name.replace(/\.[^.]+$/, '');
    return { blob, name: `${baseName}.${targetFormat}` };
  },

  // ---- Images to PDF (using pdf-lib) ----
  async imagesToPdf(files, options = {}) {
    const { PDFDocument } = PDFLib;
    const { pageSize = 'a4', orientation = 'portrait', margin = 20 } = options;
    const pageSizes = {
      a4: [595.28, 841.89],
      letter: [612, 792],
      original: null,
    };
    const doc = await PDFDocument.create();

    for (const file of files) {
      const dataUrl = await FW.file.readAsDataURL(file);
      const ext = (file.name.split('.').pop() || 'jpg').toLowerCase();

      let embeddedImage;
      if (ext === 'png') {
        embeddedImage = await doc.embedPng(dataUrl);
      } else {
        // For jpg, webp, gif → use canvas to get jpg bytes
        const img = await ImageTools._loadImage(file);
        const canvas = document.createElement('canvas');
        canvas.width = img.naturalWidth;
        canvas.height = img.naturalHeight;
        const ctx = canvas.getContext('2d');
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        ctx.drawImage(img, 0, 0);
        const jpgBytes = await new Promise(resolve => canvas.toBlob(b => b.arrayBuffer().then(resolve), 'image/jpeg', 0.92));
        embeddedImage = await doc.embedJpg(jpgBytes);
        canvas.width = 0; canvas.height = 0;
      }

      let [pw, ph] = pageSizes[pageSize] || pageSizes.a4;
      if (pageSize === 'original') {
        pw = embeddedImage.width;
        ph = embeddedImage.height;
      }
      if (orientation === 'landscape') { [pw, ph] = [ph, pw]; }

      const page = doc.addPage([pw, ph]);
      const m = margin;
      const aw = pw - m * 2;
      const ah = ph - m * 2;
      const imageAspect = embeddedImage.width / embeddedImage.height;
      const pageAspect = aw / ah;

      let drawW, drawH;
      if (imageAspect > pageAspect) {
        drawW = aw;
        drawH = aw / imageAspect;
      } else {
        drawH = ah;
        drawW = ah * imageAspect;
      }
      const x = m + (aw - drawW) / 2;
      const y = m + (ah - drawH) / 2;
      page.drawImage(embeddedImage, { x, y, width: drawW, height: drawH });
    }

    const bytes = await doc.save();
    return { blob: new Blob([bytes], { type: 'application/pdf' }), name: 'images_to_pdf.pdf' };
  },
};
