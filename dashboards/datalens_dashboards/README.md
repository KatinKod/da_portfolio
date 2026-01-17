<!-- index.html для твоего портфолио -->
<!DOCTYPE html>
<html>
<head>
    <title>Мои дашборды</title>
    <style>
        .dashboard-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
            gap: 30px;
            padding: 20px;
        }
        .dashboard-item {
            border: 1px solid #e1e4e8;
            border-radius: 10px;
            padding: 20px;
            background: white;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
    </style>
</head>
<body>
    <div class="dashboard-grid">
        <div class="dashboard-item">
            <h3>📊 Анализ Яндекс.Книги</h3>
            <iframe src="https://lookerstudio.google.com/..." width="100%" height="400"></iframe>
        </div>
    </div>
</body>
</html>
