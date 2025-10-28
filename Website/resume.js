document.addEventListener('DOMContentLoaded', () => {
    const printBtn = document.querySelector('.print-pdf-btn');
    if (printBtn) {
        printBtn.addEventListener('click', (e) => {
            e.preventDefault();
            window.print();
        });
    }

    const downloadBtn = document.getElementById('download-pdf');
    if (downloadBtn) {
        downloadBtn.addEventListener('click', async () => {
            console.log("> Deploying Resume Artifact…");
            await generateResumePDF();
        });
    }
});

export async function generateResumePDF() {
    const { jsPDF } = window.jspdf;
    const resume = document.getElementById('content');
    const qr = document.getElementById('qr-img');

    // Ensure QR image is loaded
    if (!qr.complete) {
        await new Promise(resolve => qr.onload = resolve);
    }

    // Render resume content
    const canvas = await html2canvas(resume, {
        scale: 2,
        useCORS: true
    });

    const imgData = canvas.toDataURL('image/png');
    const pdf = new jsPDF({
        orientation: 'portrait',
        unit: 'px',
        format: [canvas.width, canvas.height + 140] // extra space for QR + caption
    });

    pdf.addImage(imgData, 'PNG', 0, 0, canvas.width, canvas.height);

    // Render QR code
    const qrCanvas = await html2canvas(qr, {
        scale: 2,
        useCORS: true
    });

    pdf.save('Dan_Damit_Resume.pdf');
}