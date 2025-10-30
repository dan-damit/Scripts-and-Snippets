async function generateResumePDF() {
    const { jsPDF } = window.jspdf || window.jspdf.jsPDF;
    const resume = document.getElementById('content');

    // Render resume content
    const canvas = await html2canvas(resume, {
        scale: 2,
        useCORS: true
    });

    const imgData = canvas.toDataURL('image/png');
    const pdf = new jsPDF({
        orientation: 'portrait',
        unit: 'px',
    });

    pdf.addImage(imgData, 'PNG', 0, 0, canvas.width, canvas.height);
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