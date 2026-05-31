//Contador de palabras desde un archivo de texto
#include <iostream>
#include <fstream>
#include <string>
#include <unordered_map>
#include <chrono>
using namespace std;

void escribirContador(ofstream& salida, const unordered_map<string, int>& palabrasMap) {
    for (const auto& palabra : palabrasMap) {
        salida << palabra.first << " " << palabra.second << "\n";
    }
}

void contarPalabras(ifstream& file, int& totalPalabras, unordered_map<string, int>& palabrasMap) {
    string palabra;
    while (file >> palabra) {
        palabrasMap[palabra]++;
        totalPalabras++;
    }
}

int main() {
    ios_base::sync_with_stdio(false);
    cin.tie(NULL);

    string archivo = "texto.txt";
    string archivoSalida = "contador.txt";
    
    ifstream file(archivo);
    if (!file.is_open()) {
        cout << "Error al abrir el archivo de entrada: " << archivo << endl;
        return 0;
    }

    ofstream salida(archivoSalida);
    if (!salida.is_open()) {
        cout << "Error al abrir el archivo de salida: " << archivoSalida << endl;
        file.close();
        return 0;
    }

    unordered_map<string, int> palabrasMap;
    palabrasMap.reserve(10000); 
    int totalPalabras = 0;

    auto inicio = chrono::high_resolution_clock::now();
    
    contarPalabras(file, totalPalabras, palabrasMap);
    escribirContador(salida, palabrasMap);

    auto fin = chrono::high_resolution_clock::now();
    chrono::duration<double, milli> tiempo = fin - inicio;

    cout << "Cantidad total de palabras: " << totalPalabras << endl;
    cout << "Tiempo de ejecucion: " << tiempo.count() << " ms" << endl;
    
    salida.close();
    file.close();
    return 0;
}