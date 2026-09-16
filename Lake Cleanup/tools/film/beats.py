import sys, json, numpy as np, librosa
y, sr = librosa.load(sys.argv[1], sr=22050, mono=True)
tempo, beats = librosa.beat.beat_track(y=y, sr=sr, units='time')
tempo = float(np.atleast_1d(tempo)[0])
on = librosa.onset.onset_strength(y=y, sr=sr)
# loudness envelope per second for section guessing
rms = librosa.feature.rms(y=y)[0]
t = librosa.frames_to_time(np.arange(len(rms)), sr=sr)
sec = [float(np.mean(rms[(t>=s)&(t<s+1)])) for s in range(int(t[-1]))]
print("tempo", tempo, "beats", len(beats), "first", beats[:8].round(3).tolist())
print("rms/s", [round(v*100,1) for v in sec[:60]])
json.dump({"tempo": tempo, "beats": [round(float(b),4) for b in beats]}, open("tools/film/beats.json","w"))
