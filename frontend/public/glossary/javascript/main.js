document.addEventListener('DOMContentLoaded', function() {
    const collapsibles = document.querySelectorAll('.collapsible');
    collapsibles.forEach(button => {
        button.addEventListener('click', function() {
            this.classList.toggle('active');
            const content = this.nextElementSibling;
            content.style.display = content.style.display === 'block' ? 'none' : 'block';
        });
    });

    const searchInput = document.getElementById('search-input');
    searchInput.addEventListener('input', function() {
        const query = this.value.toLowerCase();
        const sections = document.querySelectorAll('button.collapsible');
        if (query === '') {
            // when search input is empty, show all sections and collapse them
            showAll();
            sections.forEach(section => {
                collapseSection(section);
            });
            return;
        }
        sections.forEach(section => {
            const text = section.textContent.toLowerCase();
            const content = section.nextElementSibling;
            if (text.includes(query)) {
                section.style.display = '';
                content.style.display = 'block';
            } else {
                section.style.display = 'none';
                content.style.display = 'none';
            }
        });
    });

    const fullSearchInput = document.getElementById('full-search-input');
    fullSearchInput.addEventListener('input', function() {
        const query = this.value.toLowerCase();
        if (query === '') {
            const sections = document.querySelectorAll('button.collapsible');
            // when search input is empty, show all sections and collapse them
            showAll();
            sections.forEach(section => {
                collapseSection(section);
            });
            return;
        }
        collapsibles.forEach(button => {
            const content = button.nextElementSibling;
            const fullText = (button.textContent + " " + content.textContent).toLowerCase();
            if (fullText.includes(query)) {
                button.style.display = '';
                showSection(content);
            } else {
                button.style.display = 'none';
                hideSection(content);
            }
        });
    });
});

function showSection(section) {
    section.style.display = 'block';
    section.previousElementSibling.classList.add('active');
}

function showAll() {
    const collapsibles = document.querySelectorAll('.collapsible');
    collapsibles.forEach(button => {
        button.style.display = '';
        showSection(button.nextElementSibling);
    });
}

function hideSection(section) {
    section.style.display = 'none';
    section.previousElementSibling.classList.remove('active');
}

function collapseSection(section) {
    section.classList.remove('active');
    section.nextElementSibling.style.display = 'none';
}   

function collapseAll() {
    const collapsibles = document.querySelectorAll('.collapsible');
    collapsibles.forEach(button => {
        button.classList.remove('active');
        button.nextElementSibling.style.display = 'none';
    });
}

function expandAll() {
    const collapsibles = document.querySelectorAll('.collapsible');
    collapsibles.forEach(button => {
        button.classList.add('active');
        button.nextElementSibling.style.display = 'block';
    });
}


