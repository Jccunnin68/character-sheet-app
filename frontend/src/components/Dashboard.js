import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import { toast } from 'react-toastify';

const Dashboard = () => {
  const [characters, setCharacters] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchCharacters();
  }, []);

  const fetchCharacters = async () => {
    try {
      const response = await axios.get('/api/characters');
      setCharacters(response.data);
    } catch (error) {
      toast.error('Failed to fetch characters');
    }
    setLoading(false);
  };

  const deleteCharacter = async (id) => {
    if (!window.confirm('Are you sure you want to delete this character?')) {
      return;
    }

    try {
      await axios.delete(`/api/characters/${id}`);
      setCharacters(characters.filter(char => char.id !== id));
      toast.success('Character deleted successfully');
    } catch (error) {
      toast.error('Failed to delete character');
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold text-gray-900">My Characters</h1>
        <Link
          to="/create-character"
          className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md transition-colors"
        >
          Create New Character
        </Link>
      </div>

      {characters.length === 0 ? (
        <div className="text-center py-12">
          <p className="text-gray-500 text-lg mb-4">You haven't created any characters yet.</p>
          <Link
            to="/create-character"
            className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-md transition-colors"
          >
            Create Your First Character
          </Link>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {characters.map((character) => (
            <div key={character.id} className="bg-white rounded-lg shadow-md p-6">
              <h2 className="text-xl font-semibold mb-2">{character.name}</h2>
              <p className="text-gray-600 mb-2">Class: {character.class}</p>
              <p className="text-gray-600 mb-2">Level: {character.level}</p>
              <p className="text-gray-600 mb-4">Race: {character.race}</p>
              
              <div className="flex space-x-2">
                <Link
                  to={`/character/${character.id}`}
                  className="bg-blue-600 hover:bg-blue-700 text-white px-3 py-2 rounded text-sm transition-colors"
                >
                  View
                </Link>
                <button
                  onClick={() => deleteCharacter(character.id)}
                  className="bg-red-600 hover:bg-red-700 text-white px-3 py-2 rounded text-sm transition-colors"
                >
                  Delete
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default Dashboard; 