async function generateResumePDF() {
    const { jsPDF } = window.jspdf || window.jspdf.jsPDF;
    const resume = document.getElementById('content');

    // Now safe to render
    const canvas = await html2canvas(resume, {
        scale: 2,
        useCORS: true
    });

    const imgData = canvas.toDataURL('image/JPEG');
    const pdf = new jsPDF({
        orientation: 'portrait',
        unit: 'px',
        format: [canvas.width, canvas.height]
    });

    pdf.addImage(imgData, 'JPEG', 0, 0, canvas.width, canvas.height);
    pdf.save('Dan_Damit_Resume.pdf');
}

document.addEventListener('DOMContentLoaded', () => {
    const pdfButtons = document.querySelectorAll('.pdf-btn');

    pdfButtons.forEach((btn) => {
        const id = btn.id;

        if (id === 'print-pdf') {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                window.print();
            });
        }

        if (id === 'download-pdf') {
            btn.addEventListener('click', async () => {
                await generateResumePDF();
            });
        }
    });
});