import React from 'react';
import { useForm } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import * as yup from 'yup';
import { useNavigate } from 'react-router-dom';
import { toast } from 'react-toastify';
import axios from 'axios';

const schema = yup.object({
  name: yup.string().required('Character name is required'),
  race: yup.string().required('Race is required'),
  class: yup.string().required('Class is required'),
  level: yup.number().positive('Level must be positive').integer('Level must be a whole number').required('Level is required'),
  background: yup.string().required('Background is required'),
  strength: yup.number().min(1).max(20).required('Strength is required'),
  dexterity: yup.number().min(1).max(20).required('Dexterity is required'),
  constitution: yup.number().min(1).max(20).required('Constitution is required'),
  intelligence: yup.number().min(1).max(20).required('Intelligence is required'),
  wisdom: yup.number().min(1).max(20).required('Wisdom is required'),
  charisma: yup.number().min(1).max(20).required('Charisma is required'),
});

const CreateCharacter = () => {
  const navigate = useNavigate();
  
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm({
    resolver: yupResolver(schema),
    defaultValues: {
      level: 1,
      strength: 10,
      dexterity: 10,
      constitution: 10,
      intelligence: 10,
      wisdom: 10,
      charisma: 10,
    }
  });

  const onSubmit = async (data) => {
    try {
      const response = await axios.post('/api/characters', data);
      toast.success('Character created successfully!');
      navigate(`/character/${response.data.id}`);
    } catch (error) {
      toast.error(error.response?.data?.error || 'Failed to create character');
    }
  };

  const races = ['Human', 'Elf', 'Dwarf', 'Halfling', 'Dragonborn', 'Gnome', 'Half-Elf', 'Half-Orc', 'Tiefling'];
  const classes = ['Fighter', 'Wizard', 'Cleric', 'Rogue', 'Ranger', 'Paladin', 'Barbarian', 'Bard', 'Druid', 'Monk', 'Sorcerer', 'Warlock'];
  const backgrounds = ['Acolyte', 'Criminal', 'Folk Hero', 'Noble', 'Sage', 'Soldier', 'Charlatan', 'Entertainer', 'Guild Artisan', 'Hermit', 'Outlander', 'Sailor'];

  return (
    <div className="max-w-4xl mx-auto bg-white rounded-lg shadow-md p-8">
      <h1 className="text-3xl font-bold text-center mb-8">Create New Character</h1>
      
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label htmlFor="name" className="block text-sm font-medium text-gray-700">
              Character Name
            </label>
            <input
              type="text"
              id="name"
              {...register('name')}
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            />
            {errors.name && (
              <p className="mt-1 text-sm text-red-600">{errors.name.message}</p>
            )}
          </div>

          <div>
            <label htmlFor="level" className="block text-sm font-medium text-gray-700">
              Level
            </label>
            <input
              type="number"
              id="level"
              min="1"
              max="20"
              {...register('level', { valueAsNumber: true })}
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            />
            {errors.level && (
              <p className="mt-1 text-sm text-red-600">{errors.level.message}</p>
            )}
          </div>

          <div>
            <label htmlFor="race" className="block text-sm font-medium text-gray-700">
              Race
            </label>
            <select
              id="race"
              {...register('race')}
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="">Select a race</option>
              {races.map(race => (
                <option key={race} value={race}>{race}</option>
              ))}
            </select>
            {errors.race && (
              <p className="mt-1 text-sm text-red-600">{errors.race.message}</p>
            )}
          </div>

          <div>
            <label htmlFor="class" className="block text-sm font-medium text-gray-700">
              Class
            </label>
            <select
              id="class"
              {...register('class')}
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="">Select a class</option>
              {classes.map(cls => (
                <option key={cls} value={cls}>{cls}</option>
              ))}
            </select>
            {errors.class && (
              <p className="mt-1 text-sm text-red-600">{errors.class.message}</p>
            )}
          </div>

          <div>
            <label htmlFor="background" className="block text-sm font-medium text-gray-700">
              Background
            </label>
            <select
              id="background"
              {...register('background')}
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="">Select a background</option>
              {backgrounds.map(bg => (
                <option key={bg} value={bg}>{bg}</option>
              ))}
            </select>
            {errors.background && (
              <p className="mt-1 text-sm text-red-600">{errors.background.message}</p>
            )}
          </div>
        </div>

        <div>
          <h3 className="text-lg font-medium text-gray-900 mb-4">Ability Scores</h3>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
            {['strength', 'dexterity', 'constitution', 'intelligence', 'wisdom', 'charisma'].map(ability => (
              <div key={ability}>
                <label htmlFor={ability} className="block text-sm font-medium text-gray-700 capitalize">
                  {ability}
                </label>
                <input
                  type="number"
                  id={ability}
                  min="1"
                  max="20"
                  {...register(ability, { valueAsNumber: true })}
                  className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                />
                {errors[ability] && (
                  <p className="mt-1 text-sm text-red-600">{errors[ability].message}</p>
                )}
              </div>
            ))}
          </div>
        </div>

        <div className="flex space-x-4">
          <button
            type="button"
            onClick={() => navigate('/dashboard')}
            className="flex-1 py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={isSubmitting}
            className="flex-1 py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
          >
            {isSubmitting ? 'Creating...' : 'Create Character'}
          </button>
        </div>
      </form>
    </div>
  );
};

export default CreateCharacter; 