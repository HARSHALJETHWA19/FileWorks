// ============================================================
// FileWorks — PDF Tools (uses pdf-lib, pdfjs-dist via CDN)
// ============================================================

const PdfTools = {
  // ---- Merge PDFs ----
  async merge(files, outputName = 'merged.pdf') {
    const { PDFDocument } = PDFLib;
    const mergedDoc = await PDFDocument.create();
    for (const file of files) {
      const bytes = await FW.file.readAsArrayBuffer(file);
      let srcDoc;
      try {
        srcDoc = await PDFDocument.load(bytes, { ignoreEncryption: false });
      } catch(e) {
        throw new Error(`Could not read "${file.name}". It may be encrypted or corrupted.`);
      }
      const pageIndices = srcDoc.getPageIndices();
      const copiedPages = await mergedDoc.copyPages(srcDoc, pageIndices);
      copiedPages.forEach(p => mergedDoc.addPage(p));
    }
    const bytes = await mergedDoc.save();
    return new Blob([bytes], { type: 'application/pdf' });
  },

  // ---- Split PDF by page numbers ----
  async split(file, pageNumbers) {
    const { PDFDocument } = PDFLib;
    const srcBytes = await FW.file.readAsArrayBuffer(file);
    let srcDoc;
    try {
      srcDoc = await PDFDocument.load(srcBytes);
    } catch(e) {
      throw new Error(`Could not read "${file.name}". It may be encrypted or corrupted.`);
    }
    const totalPages = srcDoc.getPageCount();
    const validPages = pageNumbers.filter(n => n >= 1 && n <= totalPages);
    if (validPages.length === 0) throw new Error('No valid page numbers specified.');

    const results = [];
    for (const pageNum of validPages) {
      const newDoc = await PDFDocument.create();
      const [copied] = await newDoc.copyPages(srcDoc, [pageNum - 1]);
      newDoc.addPage(copied);
      const bytes = await newDoc.save();
      const baseName = file.name.replace(/\.pdf$/i, '');
      results.push({
        blob: new Blob([bytes], { type: 'application/pdf' }),
        name: `${baseName}_page_${pageNum}.pdf`,
      });
    }
    return results;
  },

  // ---- Split PDF into ranges ----
  async splitRanges(file, ranges) {
    const { PDFDocument } = PDFLib;
    const srcBytes = await FW.file.readAsArrayBuffer(file);
    let srcDoc;
    try {
      srcDoc = await PDFDocument.load(srcBytes);
    } catch(e) {
      throw new Error(`Could not read "${file.name}". It may be encrypted or corrupted.`);
    }
    const totalPages = srcDoc.getPageCount();
    const results = [];
    for (let i = 0; i < ranges.length; i++) {
      const { from, to } = ranges[i];
      const f = Math.max(1, from);
      const t = Math.min(totalPages, to);
      if (f > t) continue;
      const newDoc = await PDFDocument.create();
      const indices = [];
      for (let p = f; p <= t; p++) indices.push(p - 1);
      const copied = await newDoc.copyPages(srcDoc, indices);
      copied.forEach(p => newDoc.addPage(p));
      const bytes = await newDoc.save();
      const baseName = file.name.replace(/\.pdf$/i, '');
      results.push({
        blob: new Blob([bytes], { type: 'application/pdf' }),
        name: `${baseName}_part_${i + 1}.pdf`,
      });
    }
    return results;
  },

  // ---- Rotate PDF pages ----
  async rotate(file, rotations, outputName) {
    const { PDFDocument, degrees } = PDFLib;
    const srcBytes = await FW.file.readAsArrayBuffer(file);
    let doc;
    try {
      doc = await PDFDocument.load(srcBytes);
    } catch(e) {
      throw new Error(`Could not read "${file.name}".`);
    }
    const pages = doc.getPages();
    pages.forEach((page, i) => {
      const deg = rotations[i + 1] || 0;
      if (deg !== 0) {
        const current = page.getRotation().angle;
        page.setRotation(degrees((current + deg) % 360));
      }
    });
    const bytes = await doc.save();
    return { blob: new Blob([bytes], { type: 'application/pdf' }), name: outputName };
  },

  // ---- Reorder PDF pages ----
  async reorder(file, newOrder, outputName) {
    const { PDFDocument } = PDFLib;
    const srcBytes = await FW.file.readAsArrayBuffer(file);
    let srcDoc;
    try {
      srcDoc = await PDFDocument.load(srcBytes);
    } catch(e) {
      throw new Error(`Could not read "${file.name}".`);
    }
    const newDoc = await PDFDocument.create();
    const indices = newOrder.map(n => n - 1);
    const copied = await newDoc.copyPages(srcDoc, indices);
    copied.forEach(p => newDoc.addPage(p));
    const bytes = await newDoc.save();
    return { blob: new Blob([bytes], { type: 'application/pdf' }), name: outputName };
  },

  // ---- Compress PDF (optimization via pdf-lib re-save) ----
  async compress(file, outputName) {
    const { PDFDocument } = PDFLib;
    const srcBytes = await FW.file.readAsArrayBuffer(file);
    let doc;
    try {
      doc = await PDFDocument.load(srcBytes, { updateMetadata: false });
    } catch(e) {
      throw new Error(`Could not read "${file.name}".`);
    }
    // pdf-lib's objectsPerTick and useObjectStreams reduce file size
    const bytes = await doc.save({ useObjectStreams: true, addDefaultPage: false });
    return { blob: new Blob([bytes], { type: 'application/pdf' }), name: outputName };
  },

  // ---- Get page count ----
  async getPageCount(file) {
    const { PDFDocument } = PDFLib;
    const bytes = await FW.file.readAsArrayBuffer(file);
    const doc = await PDFDocument.load(bytes, { ignoreEncryption: false });
    return doc.getPageCount();
  },

  // ---- PDF to Images (uses pdfjs-dist) ----
  async pdfToImages(file, pageNumbers, format = 'jpeg', quality = 0.9, onProgress = null) {
    const results = [];
    const arrayBuffer = await FW.file.readAsArrayBuffer(file);
    const loadingTask = pdfjsLib.getDocument({ data: arrayBuffer });
    const pdfDoc = await loadingTask.promise;
    const total = pageNumbers ? pageNumbers.length : pdfDoc.numPages;

    for (let i = 0; i < pageNumbers.length; i++) {
      const pageNum = pageNumbers[i];
      if (pageNum < 1 || pageNum > pdfDoc.numPages) continue;
      const page = await pdfDoc.getPage(pageNum);
      const viewport = page.getViewport({ scale: 2.0 });

      const canvas = document.createElement('canvas');
      canvas.width = viewport.width;
      canvas.height = viewport.height;
      const ctx = canvas.getContext('2d');

      await page.render({ canvasContext: ctx, viewport }).promise;

      const mimeType = format === 'png' ? 'image/png' : 'image/jpeg';
      const blob = await new Promise(resolve => canvas.toBlob(resolve, mimeType, quality));
      const baseName = file.name.replace(/\.pdf$/i, '');
      const ext = format === 'png' ? 'png' : 'jpg';
      results.push({ blob, name: `${baseName}_page_${pageNum}.${ext}` });

      if (onProgress) onProgress(i + 1, pageNumbers.length);
      canvas.width = 0; canvas.height = 0; // free memory
    }
    return results;
  },
};
