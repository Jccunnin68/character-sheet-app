import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import axios from 'axios';
import { toast } from 'react-toastify';

const CharacterSheet = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const [character, setCharacter] = useState(null);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(false);

  useEffect(() => {
    fetchCharacter();
  }, [id]);

  const fetchCharacter = async () => {
    try {
      const response = await axios.get(`/api/characters/${id}`);
      setCharacter(response.data);
    } catch (error) {
      toast.error('Failed to fetch character');
      navigate('/dashboard');
    }
    setLoading(false);
  };

  const updateCharacter = async (updates) => {
    try {
      const response = await axios.put(`/api/characters/${id}`, updates);
      setCharacter(response.data);
      toast.success('Character updated successfully');
    } catch (error) {
      toast.error('Failed to update character');
    }
  };

  const getModifier = (score) => {
    return Math.floor((score - 10) / 2);
  };

  const formatModifier = (modifier) => {
    return modifier >= 0 ? `+${modifier}` : `${modifier}`;
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  if (!character) {
    return <div>Character not found</div>;
  }

  return (
    <div className="max-w-4xl mx-auto bg-white rounded-lg shadow-md p-8">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold text-gray-900">{character.name}</h1>
        <div className="space-x-2">
          <button
            onClick={() => setEditing(!editing)}
            className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded transition-colors"
          >
            {editing ? 'Cancel' : 'Edit'}
          </button>
          <button
            onClick={() => navigate('/dashboard')}
            className="bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded transition-colors"
          >
            Back to Dashboard
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
        <div className="bg-gray-50 p-4 rounded-lg">
          <h3 className="font-semibold text-gray-700 mb-2">Basic Info</h3>
          <p><strong>Race:</strong> {character.race}</p>
          <p><strong>Class:</strong> {character.class}</p>
          <p><strong>Level:</strong> {character.level}</p>
          <p><strong>Background:</strong> {character.background}</p>
        </div>

        <div className="bg-gray-50 p-4 rounded-lg">
          <h3 className="font-semibold text-gray-700 mb-2">Hit Points</h3>
          <p><strong>Max HP:</strong> {character.max_hp || 'Not set'}</p>
          <p><strong>Current HP:</strong> {character.current_hp || 'Not set'}</p>
        </div>

        <div className="bg-gray-50 p-4 rounded-lg">
          <h3 className="font-semibold text-gray-700 mb-2">Armor Class</h3>
          <p><strong>AC:</strong> {character.armor_class || 'Not set'}</p>
        </div>
      </div>

      <div className="mb-8">
        <h2 className="text-2xl font-bold text-gray-900 mb-4">Ability Scores</h2>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
          {['strength', 'dexterity', 'constitution', 'intelligence', 'wisdom', 'charisma'].map(ability => {
            const score = character[ability];
            const modifier = getModifier(score);
            
            return (
              <div key={ability} className="bg-gray-50 p-4 rounded-lg text-center">
                <h4 className="font-semibold text-gray-700 capitalize mb-2">{ability}</h4>
                <div className="text-2xl font-bold text-gray-900">{score}</div>
                <div className="text-sm text-gray-600">{formatModifier(modifier)}</div>
              </div>
            );
          })}
        </div>
      </div>

      {character.notes && (
        <div className="mb-8">
          <h2 className="text-2xl font-bold text-gray-900 mb-4">Notes</h2>
          <div className="bg-gray-50 p-4 rounded-lg">
            <p className="whitespace-pre-wrap">{character.notes}</p>
          </div>
        </div>
      )}

      <div className="text-sm text-gray-500">
        <p>Created: {new Date(character.created_at).toLocaleDateString()}</p>
        {character.updated_at && (
          <p>Last Updated: {new Date(character.updated_at).toLocaleDateString()}</p>
        )}
      </div>
    </div>
  );
};

export default CharacterSheet; 