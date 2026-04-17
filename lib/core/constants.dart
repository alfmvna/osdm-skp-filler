/// Konstanta API dan data SKP OSDM
class ApiConstants {
  static const String baseUrl = 'https://osdm.kemdiktisaintek.go.id/skp';
  static const String loginUrl = '$baseUrl/site/login';
  static const String calendarUrl = '$baseUrl/pegawai/logharian/cal';
  static const String saveLogUrl = '$baseUrl/pegawai/logharian/save';
  static const String getDataAjaxUrl = '$baseUrl/pegawai/logharian/getDataAjax';
  static const String rekapUrl = '$baseUrl/pegawai/logharian/rekap';
}

/// Grup SKP dengan indikatornya
class SkpGroups {
  static const Map<String, List<String>> groups = {
    'Pengadaan Barang & Jasa': [
      'kualitatif_1799526',
      'kualitatif_1799527',
      'kualitatif_1799528',
      'kualitatif_1799529',
    ],
    'Laboratorium & Sarana': [
      'kualitatif_1799421',
      'kualitatif_1799422',
      'kualitatif_1799423',
      'kualitatif_1799424',
      'kualitatif_1799426',
      'kualitatif_1799427',
      'kualitatif_1799428',
    ],
    'Inventaris & Aset': [
      'kualitatif_1799540',
      'kualitatif_1799541',
      'kualitatif_1799542',
      'kualitatif_1799543',
      'kualitatif_1799544',
    ],
    'Website & Digital': [
      'kualitatif_1799656',
      'kualitatif_1799657',
      'kualitatif_1799658',
      'kualitatif_1799659',
      'kualitatif_1799660',
    ],
    'Monitoring & Evaluasi': [
      'kualitatif_1813101',
      'kualitatif_1813102',
      'kualitatif_1813103',
      'kualitatif_1813104',
      'kualitatif_1813105',
    ],
    'Penugasan Umum': [
      'kualitatif_1799623',
      'kualitatif_1799624',
      'kualitatif_1799625',
      'kualitatif_1799626',
      'kualitatif_1799627',
    ],
  };

  static const Map<String, String> indicatorNames = {
    'kualitatif_1799526': 'Paket pengadaan yang didukung...',
    'kualitatif_1799527': 'Dokumen pengadaan dan BAST ...',
    'kualitatif_1799528': 'Tidak ada keterlambatan realisas...',
    'kualitatif_1799529': 'Monitoring progres pengadaan...',
    'kualitatif_1799421': 'Checklist perawatan sarpras',
    'kualitatif_1799422': 'Ketersediaan sarpras siap pakai',
    'kualitatif_1799423': 'Laporan inventaris tersedia',
    'kualitatif_1799424': 'Perbaikan dilakukan sesuai SOP',
    'kualitatif_1799426': 'Tingkat kesiapan laboratorium',
    'kualitatif_1799427': 'Tidak ada pembatalan praktis',
    'kualitatif_1799428': 'Instalasi software pembelajaran',
    'kualitatif_1799540': 'Transaksi masuk dan keluar ...',
    'kualitatif_1799541': 'Opname fisik dilaksanakan ...',
    'kualitatif_1799542': 'Tidak terdapat selisih material',
    'kualitatif_1799543': 'Neraca persediaan disusun ...',
    'kualitatif_1799544': 'Dokumen dukung transaksi ...',
    'kualitatif_1799656': 'Pembaruan konten website ...',
    'kualitatif_1799657': 'Publikasi kegiatan jurusan ...',
    'kualitatif_1799658': 'Ketersediaan layanan website',
    'kualitatif_1799659': 'Pengelolaan server dan storage',
    'kualitatif_1799660': 'Backup data dan pengarsipan',
    'kualitatif_1813101': 'Persentase implementasi SOP',
    'kualitatif_1813102': 'Tidak terdapat temuan ...',
    'kualitatif_1813103': 'Kelengkapan dan ketersediaan ...',
    'kualitatif_1813104': 'Pelaksanaan monitoring dan ...',
    'kualitatif_1813105': 'Tindak lanjut atas rekomendasi',
    'kualitatif_1799623': 'Minimal 5 penugasan ...',
    'kualitatif_1799624': 'Seluruh tugas dan tanggung ...',
    'kualitatif_1799625': 'Output kegiatan berupa dokumen',
    'kualitatif_1799626': 'Partisipasi aktif dalam program',
    'kualitatif_1799627': 'Seluruh bukti dukung kegiatan',
  };

  static String getIndicatorName(String key) {
    return indicatorNames[key] ?? key;
  }
}
