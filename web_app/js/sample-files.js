// ============================================================
// FileWorks — Client-Side Sample File Generator Module
// Generates test fixtures directly in browser memory for instant evaluation.
// ============================================================

const SampleFiles = {
  /**
   * Generates a clean synthetic PDF file in memory using PDFLib.
   */
  async createSamplePdf(name = 'sample-document.pdf', pageCount = 3, title = 'FileWorks Sample Document') {
    if (!window.PDFLib) {
      throw new Error('PDFLib is required to generate sample PDFs.');
    }
    const { PDFDocument, rgb, StandardFonts } = window.PDFLib;
    const doc = await PDFDocument.create();
    const font = await doc.embedFont(StandardFonts.Helvetica);
    const fontBold = await doc.embedFont(StandardFonts.HelveticaBold);

    for (let i = 1; i <= pageCount; i++) {
      // Standard A4: 595.28 x 841.89
      const page = doc.addPage([595.28, 841.89]);
      const { width, height } = page.getSize();

      // Top banner
      page.drawRectangle({
        x: 40,
        y: height - 100,
        width: width - 80,
        height: 60,
        color: rgb(0.1, 0.45, 0.9),
      });

      page.drawText(title, {
        x: 55,
        y: height - 70,
        size: 20,
        font: fontBold,
        color: rgb(1, 1, 1),
      });

      page.drawText(`Page ${i} of ${pageCount} — Evaluation & Verification Fixture`, {
        x: 55,
        y: height - 90,
        size: 11,
        font,
        color: rgb(0.85, 0.92, 1),
      });

      // Sample content block
      page.drawText(`ISO Standard A4 Document (210 × 297 mm)`, {
        x: 50,
        y: height - 140,
        size: 14,
        font: fontBold,
        color: rgb(0.2, 0.2, 0.2),
      });

      const sampleLines = [
        `• Generated client-side for testing FileWorks tools.`,
        `• Demonstrates high-fidelity vector rendering and text preservation.`,
        `• Useful for testing PDF Merge, Split, Rotation, Reordering, and Compression.`,
        `• Zero server uploads required. 100% browser sandbox execution.`,
        `• Resolution: 72 DPI base points (595.28 pt × 841.89 pt).`,
      ];

      sampleLines.forEach((line, idx) => {
        page.drawText(line, {
          x: 50,
          y: height - 180 - (idx * 22),
          size: 11,
          font,
          color: rgb(0.3, 0.3, 0.3),
        });
      });

      // Footer
      page.drawText(`FileWorks Verification Test Document • Page ${i}`, {
        x: 50,
        y: 40,
        size: 9,
        font,
        color: rgb(0.5, 0.5, 0.5),
      });
    }

    const pdfBytes = await doc.save();
    return new File([pdfBytes], name, { type: 'application/pdf' });
  },

  /**
   * Generates a sample image using HTML5 Canvas.
   */
  async createSampleImage(name = 'sample-image.jpg', width = 1200, height = 800, format = 'image/jpeg') {
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext('2d');

    // Gradient background
    const grad = ctx.createLinearGradient(0, 0, width, height);
    grad.addColorStop(0, '#1e3a8a');
    grad.addColorStop(0.5, '#2563eb');
    grad.addColorStop(1, '#06b6d4');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, width, height);

    // Decorative geometric grid
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.15)';
    ctx.lineWidth = 2;
    for (let x = 0; x < width; x += 100) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, height);
      ctx.stroke();
    }
    for (let y = 0; y < height; y += 100) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
    }

    // Centered Badge
    ctx.fillStyle = 'rgba(255, 255, 255, 0.95)';
    ctx.font = 'bold 54px system-ui, -apple-system, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('FileWorks Sample Image', width / 2, height / 2 - 20);

    ctx.font = '32px system-ui, -apple-system, sans-serif';
    ctx.fillStyle = 'rgba(255, 255, 255, 0.85)';
    ctx.fillText(`${width} × ${height} px • ${(width * height / 1000000).toFixed(2)} Megapixels`, width / 2, height / 2 + 35);

    ctx.font = '20px system-ui, -apple-system, sans-serif';
    ctx.fillText('Client-side test fixture for Image Compression, Resize, & Transcoding', width / 2, height / 2 + 80);

    const blob = await new Promise(resolve => canvas.toBlob(resolve, format, 0.92));
    canvas.width = 0; canvas.height = 0;
    return new File([blob], name, { type: format });
  },

  /**
   * Generates a sample ZIP archive in memory using JSZip.
   */
  async createSampleZip(name = 'sample-archive.zip') {
    if (!window.JSZip) {
      throw new Error('JSZip is required to generate sample ZIP archives.');
    }
    const zip = new window.JSZip();
    zip.file('readme.txt', 'Welcome to FileWorks!\nThis is a sample text document inside an in-memory ZIP archive.\nTesting client-side ZIP extraction.');
    zip.file('notes.txt', 'Project Notes:\n1. 100% Client-side sandbox processing.\n2. Zero server uploads.\n3. Verified safe path traversal handling.');
    zip.file('data.csv', 'id,tool,format,status\n1,PDF Merge,pdf,verified\n2,Image Compress,jpg,verified\n3,ZIP Extract,zip,verified\n');

    const folder = zip.folder('documents');
    folder.file('project-plan.txt', 'FileWorks AdSense Approval Readiness Plan & Verification.');

    const blob = await zip.generateAsync({ type: 'blob', compression: 'DEFLATE' });
    return new File([blob], name, { type: 'application/zip' });
  },
};

if (typeof window !== 'undefined') {
  window.SampleFiles = SampleFiles;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = SampleFiles;
}
