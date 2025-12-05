import React, { useEffect, useState } from "react";
import axios from "axios";

function App() {
  const [tasks, setTasks] = useState([]);

  // Fetch tasks due today
  const fetchTasks = async () => {
    try {
      const res = await axios.get(
        `${process.env.REACT_APP_API_URL}/tasks/today`
      );
      setTasks(res.data);
    } catch (err) {
      console.error(err);
    }
  };

  // Mark a task as completed
  const completeTask = async (id) => {
    try {
      await axios.post(`${process.env.REACT_APP_API_URL}/tasks/${id}/complete`);
      fetchTasks(); // refresh list
    } catch (err) {
      console.error(err);
    }
  };

  useEffect(() => {
    fetchTasks();
  }, []);

  return (
    <div style={{ padding: "30px", fontFamily: "Arial" }}>
      <h2>Today's Tasks</h2>

      {tasks.length === 0 ? (
        <p>No tasks due today 😊</p>
      ) : (
        <ul>
          {tasks.map((task) => (
            <li key={task.id} style={{ marginBottom: "10px" }}>
              <b>{task.task_type.toUpperCase()}</b> — Due at:{" "}
              {new Date(task.due_at).toLocaleString()}
              {!task.is_completed && (
                <button
                  onClick={() => completeTask(task.id)}
                  style={{
                    marginLeft: "10px",
                    padding: "4px 10px",
                    cursor: "pointer",
                  }}
                >
                  Mark Completed
                </button>
              )}
              {task.is_completed && <span> ✔ Completed</span>}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

export default App;
