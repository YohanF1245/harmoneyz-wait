import React from 'react';
import { Music4, Stars, Heart, Sparkles } from 'lucide-react';
import logoSvg from '../assets/logo.svg';

function App() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-purple-900 via-purple-800 to-purple-600 flex items-center justify-center p-4">
      <div className="max-w-3xl mx-auto text-center relative">
        {/* Floating icons animation */}
        <div className="absolute -top-16 -left-8 text-purple-300/30 animate-float">
          <Music4 size={48} />
        </div>
        <div className="absolute top-0 -right-12 text-purple-300/30 animate-float-delayed">
          <Stars size={36} />
        </div>
        <div className="absolute -bottom-12 -left-16 text-purple-300/30 animate-float">
          <Heart size={32} />
        </div>
        <div className="absolute -bottom-8 -right-8 text-purple-300/30 animate-float-delayed">
          <Sparkles size={40} />
        </div>

        {/* Main content */}
        <div className="bg-white/10 backdrop-blur-lg rounded-2xl p-8 md:p-12 shadow-2xl border border-purple-300/20">
          <div className="w-28 h-28 mx-auto mb-6 rounded-full bg-white flex items-center justify-center p-2 border-2 border-white shadow-lg">
            <img 
              src={logoSvg} 
              alt="Harmoneyz Logo" 
              className="w-20 h-20"
            />
          </div>
          <h1 className="text-4xl md:text-6xl font-bold text-white mb-6 tracking-tight">
            Harmoneyz
          </h1>
          <div className="w-24 h-1 bg-gradient-to-r from-purple-400 to-pink-400 mx-auto mb-8 rounded-full"></div>
          <p className="text-xl md:text-2xl text-purple-100 mb-8 leading-relaxed">
            Une nouvelle harmonie arrive bientôt dans votre univers musical...
          </p>
          <p className="text-lg text-purple-200 mb-12">
            Notre équipe travaille avec passion pour vous offrir une expérience musicale unique et innovante.
          </p>
          <div className="inline-flex items-center gap-2 bg-purple-500/20 px-6 py-3 rounded-full border border-purple-400/30 text-purple-100 hover:bg-purple-500/30 transition-all duration-300">
            <Sparkles size={20} />
            <span>Préparez-vous pour quelque chose de magique</span>
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;