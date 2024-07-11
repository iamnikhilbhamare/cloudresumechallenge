// Function to fetch visitor count from backend
function fetchVisitorCount() {
  fetch('https://eth68ce8dl.execute-api.us-east-1.amazonaws.com/visitorcounters')
    .then(response => response.json())
    .then(data => {
      // Update counter element on the webpage with the received count
      document.getElementById('count').innerText = data.count; // Assuming the count is returned as JSON with key 'count'
    })
    .catch(error => {
      console.error('Error fetching visitor count:', error);
    });
}

// Call fetchVisitorCount function when the page loads
window.onload = fetchVisitorCount;
